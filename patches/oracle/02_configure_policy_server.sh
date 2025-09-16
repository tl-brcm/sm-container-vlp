#!/bin/bash

## This script initializes the Policy Server configuration files.
## If this script runs on an administrative policy server, it will initialize the policy store (in case it's not already initialized).
## If this script runs on a policy server, it will wait for the policy store to be initialized before starting.

## Constants
#set -x
shopt -s nocasematch
touch /tmp/runTool.sh
chmod +x /tmp/runTool.sh

touch /tmp/storeInitDetails.sh
chmod +x /tmp/storeInitDetails.sh

SOURCEPATH=`head -n 1 /configuration/.configurationSourcePath.txt`

if [ -z "${SOURCEPATH}" ]; then
    CUSTOMER_IMPORT_FILES=/configuration/$CONTAINER_LABEL/data/objects
    CUSTOMER_KEY_FILES=/configuration/$CONTAINER_LABEL/data/keys
else
    CUSTOMER_IMPORT_FILES=${SOURCEPATH}/$CONTAINER_LABEL/data/objects
    CUSTOMER_KEY_FILES=${SOURCEPATH}/$CONTAINER_LABEL/data/keys
fi

BASE_IMPORT_FILES=/initialization/data/objects
STORE_AVAILABILITY_TIME_OUT=30

echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Processing secrets"
$PS_HOME/bin/smSecretProcessor.sh -decryptk8sSecrets $MASTERKEYSEED 1>/tmp/runTool.sh
source /tmp/runTool.sh


BOOTSTRAP_FETCH_TIME_OUT=600
if [ "$ROLE" != "admin" ]; then
    if [ $POLICY_SERVER_INIT_TIMEOUT -gt  0 ]; then
        BOOTSTRAP_FETCH_TIME_OUT=$POLICY_SERVER_INIT_TIMEOUT
    fi
fi
##Adding this symlink to fix perl scripts related issue in automation
ln -s /usr/lib64/libnsl.so.2 /opt/CA/siteminder/bin/libnsl.so.1

grep -rl "]] then"  /opt/CA/siteminder/ --exclude-dir=CLI | xargs sed -i "s|]] then|]]; then|g"

POLICY_STORE_VERIFICATION_ATTRIBUTE="CA.SM::Domain"
XDD_VERSION="CA.SM::\$StoreVersion"
XPSDICTIONARY_MATCH_STRING="Class: Domain"
LDIF_SCHEMA_DN="dn: CN=smDomainOID4,CN=Schema,CN=Configuration,"
AD_SCHEMA_DN_PREFIX="CN=Schema,CN=Configuration,"
# XID HCO "localhost-psprobe-container"
XID_HCO_PSPROBE="21-00020224-365a-1cd9-ac5a-3b81c0a80000"
POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR="ou=smpolicystoreinitialized"
POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR_DN="${POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR},${POLICY_STORE_ROOT_DN}"
CREATEONLY_DSN="YES"
POLICY_STORE_ODBC_CON_FAILURE=99
#smconfigtool operations, like DB Setting or Registry setting
#SMDBCONFIG, SMREGCONFIG , SESSION_LDAP or POLICY_STORE_INITCHECK
TOOLOPERATION=""
#policy server registry keys
SMTRACECONF="smtraceconf=/opt/CA/siteminder/config/smtracedefault.txt"
SMAUDIT_LOGGING_TEXTFILE="/proc/1/fd/1"
SMINMEMORYCONF="sminmemoryconf=/opt/CA/siteminder/config/sminmemorytracedefault.txt"
SMINMEMORYENABLE="sminmemoryenable="
SMINMEMORYSIZE="sminmemorysize="
SMINMEMORY_FILEPATH="sminmemoryfilepath="
SMAUDIT_FILEPATH="smauditfilepath="
SMAUDIT_USERACTIVITY="smaudituseractivity="
SMAUDIT_ADMIN_STORE_ACTIVITY="smauditadminstoreactivity="
SMADMIN_AUDITING="smadminauditing="
SMAUTH_AUDITING="smauthauditing="
SMAZ_AUDITING="smazauditing="
SMAUTH_ANON_AUDITING="smanonauthaudit="
SMAZ_ANON_AUDITING="smanonazaudit="
SMAFFILIATE_AUDITING="smaffiliateaudit="
SMRADIUS_ENABLED="enableradius=YES"
SMENABLEKEYGENERATION="smenablekeygeneration=NO"
SMENABLEKEYUPDATEPREFIX="smenablekeyupdate="
SMKEYSTORE_ENCRYPTION_KEY="smkeystoreencryptionkey=";


# SiteMinder DN
SITEMINDER_DN="ou=PolicySvr4,ou=SiteMinder,ou=Netegrity"

# Total SM and XPS schema class counts since 12.52 onwards
# CA Directory has extra 6 class for session store, embedded in SM class
TOTAL_SM_CLASS_COUNT="38"
TOTAL_XPS_CLASS_COUNT="4"
TOTAL_SM_SS_CLASS_COUNT="44"


#for SSO-IDM Integration: schema check
IDM_SCHEMA_VERIFICATION_ATTRIBUTE="CA.SM::UserPolicy.IMSEnvironmentLink"
IDM_XPSDICTIONARY_MATCH_STRING="Matches Attribute"

#for parsing store host and port and for failover support
STORE_HOST=""
STORE_PORT=""
ADDITIONAL_HOST_STRINGS=""
POLICY_STORE_ADDITIONAL_HOSTS=""
KEY_STORE_ADDITIONAL_HOSTS=""
SESSION_STORE_ADDITIONAL_HOSTS=""
POLICY_STORE_ADDITIONAL_DSNS=""
KEY_STORE_ADDITIONAL_DSNS=""
AUDIT_STORE_ADDITIONAL_DSNS=""
SESSION_STORE_ADDITIONAL_DSNS=""
MIN_ENTROPY_LEVEL=2000


## Functions

#Update the error string
update_error_string()
{
  ERROR_STRING=$1
  echo "[*][$(date +"%T")] - ($ERROR_STRING)" > $TERMINATION_MSG_PATH

}
#Validate system entropy level, warn if its too low
entroy_check() {
    CURRENT_ENTROPY=`cat /proc/sys/kernel/random/entropy_avail`
    if [ ${MIN_ENTROPY_LEVEL} -ge ${CURRENT_ENTROPY} ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Warn: Entropy level(randomness) in system seems low!"
    fi
}

#Re-Setting sm.registry to default values.
defaultValues() {
    
    if [ -f "${SMREGFILE}" ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - ${SMREGFILE} exists, re-setting few default values."
        TOOLOPERATION="MODIFYSMREG"
    
        #EncryptionKey
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "MasterKeyFile" "$PS_HOME/bin/EncryptionKey.txt" "REG_SZ"
    
        ##SMPS Logs need to reset, as it impacts PS start if path is different than /opt/CA/siteminder.
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "LogFile" "/proc/1/fd/1" "REG_SZ"
    
        #Disabling smtrace for policy server
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TraceConfig" "" "REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TraceOutput" "/proc/1/fd/1" "REG_SZ"

        #Separate KeyStore password is not supported via yaml, once that is supported . this value needs to added with bounded check
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\ObjectStore"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "KeyStoreEncryptionKey" "" "REG_SZ"

        #Reset key store to use deafult as policystore, based on type.
        if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
            SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Use Default" "0x1" "REG_DWORD"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Enabled" "0x1" "REG_DWORD"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Use SSL" "0x0" "REG_DWORD"
        
            SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Enabled" "0x0" "REG_DWORD"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Use Default" "0x1" "REG_DWORD"
        else 
            SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Use Default" "0x1" "REG_DWORD"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Enabled" "0x1" "REG_DWORD"
        
            SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Enabled" "0x0" "REG_DWORD"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Use Default" "0x1" "REG_DWORD"
        fi

        # Session Store disabling 
        if [[ "$CA_SM_PS_ENABLE_SESSION_STORE" = "NO" ]]; then
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\SessionServer"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Enabled" "0x0" "REG_SZ"
        fi

        #Audit Store Resetting to text.
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Reports"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "LogAccess" "0x1" "REG_DWORD"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TxtLogFile" "/proc/1/fd/1" "REG_SZ"
		$PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverOnStart" "0x0" "REG_DWORD"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverSize" "0x0" "REG_DWORD"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Log"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "ProviderNamespace" "TEXT:" "REG_SZ"

        #Event handler reset
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\EventProvider"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Provider" "$PS_HOME/lib/libXPSAudit.so" "REG_SZ"

        #Publishfile
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Publish"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "PublishFile" "$PS_HOME/log/smpublish.XML" "REG_SZ"
    
        #Disabling sminmemorytrace for policy server
        if [[ "$CA_SM_PS_INMEMORY_TRACE_ENABLE" = "NO" ]]; then
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "InMemoryTraceConfig" "$PS_HOME/config/sminmemorytracedefault.txt" "REG_SZ"
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "InMemoryTraceFilePath" "$PS_HOME/log/" "REG_SZ"

           TOOLOPERATION="SMREGCONFIG"
           SMINMEMORYENABLE="$SMINMEMORYENABLE$CA_SM_PS_INMEMORY_TRACE_ENABLE"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMINMEMORYENABLE
        fi

        # Disable IM and SM Integration
        if [[ "$CA_SM_PS_ENABLE_CA_IDENITITY_MANAGER_INTEGRATION" = "NO" ]]; then
            imString=`grep ImsInstalled $PS_HOME/registry/sm.registry | wc -l`
            if [ $imString -gt 0 ];   then
              TOOLOPERATION="MODIFYSMREG"
              echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - IM registry exists"
              SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion"
              $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "ImsInstalled" "" "REG_SZ"
            fi
        fi
    
    # Resetting to default ports, as these are internal and custom port should be exposed to service.
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\PolicyServer"
    TOOLOPERATION="MODIFYSMREG"
    #sample test
    #Acct Tcp Port = 44441
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Acct Tcp Port" "0xad99" "REG_DWORD"
    #Acct Udp Port = 1646
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Acct Udp Port" "0x66e" "REG_DWORD"
    #Adm Tcp Port = 44444
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Adm Tcp Port" "0xad9c" "REG_DWORD"
    #Adm Udp Port = 44444
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Adm Udp Port" "0xad9c" "REG_DWORD"
    #Auth Tcp Port = 44442
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Auth Tcp Port" "0xad9a" "REG_DWORD"
    #Auth Udp Port = 1645
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Auth Udp Port" "0x66d" "REG_DWORD"
    #Az Tcp Port = 44443
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Az Tcp Port" "0xad9b" "REG_DWORD"
            
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring sm.registry default values - Completed"
    fi
  
}

enableTags() {
    #Enable Tag field by default for all Logs
    sed -i 's/ Function,/ Function, Tag,/g'  $PS_HOME/config/smtracedefault.txt
    TOOLOPERATION="MODIFYSMREG"
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "Tag" "0x1" "REG_DWORD"

    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "LogFile" "/proc/1/fd/1" "REG_SZ"

    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LogConfig"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TraceOutput" "/proc/1/fd/1" "REG_SZ"
	
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverOnStart" "0x0" "REG_DWORD"

    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverSize" "0x0" "REG_DWORD"

    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TraceRolloverOnStart" "0x0" "REG_DWORD"

    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "TraceRolloverSize" "0x0" "REG_DWORD"
	
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Reports"
	
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverOnStart" "0x0" "REG_DWORD"

    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "RolloverSize" "0x0" "REG_DWORD"

}


# This function is to parse store host strings. 
#Argument1: Store host String (ex: host1:port1,host2:port2 OR DSN1,DSN2)
#Argument2: Store type (ex: ODBC/LDAP)
#IPV6 supported format [2001:1bc:1234::239]:port
parse_store_host_strings()
{
    HOST_STRINGS=$1
    STORE_TYPE=$2
    FOUND="false"
    STORE_HOST=""
    STORE_PORT=""
    ADDITIONAL_HOST_STRINGS=""
    declare -ga array
    IFS=$'\n' array=($(echo "$HOST_STRINGS" | sed "s/,/\n/g"))
    for i in "${array[@]}"
do
    if [[ "$FOUND" == "false" ]]; then
        FOUND="true"

        # Separating HOST and PORT based on last colon (:) in string
        case $i in
        (*:*) STORE_HOST=${i%:*} STORE_PORT=${i##*:};;
        (*)   STORE_HOST=$i      STORE_PORT="";;
        esac
        
        #For ODBC stores, parsing IPV6 address by removing [ and ]
        if [[ "$STORE_TYPE" = "ODBC" ]] ; then
            if [[ "${STORE_HOST}" == \[* ]] && [[ "${STORE_HOST}" == *\] ]]; then
                    STORE_HOST=${STORE_HOST:1:-1}
            fi
        fi

    else
        if [[ "$STORE_TYPE" = "ODBC" ]] ; then
            ADDITIONAL_HOST_STRINGS="$ADDITIONAL_HOST_STRINGS,$i"
        else
            ADDITIONAL_HOST_STRINGS="$ADDITIONAL_HOST_STRINGS $i"
        fi
    fi
done

}

wait_for_policy_store_to_start()
{
    i=0
    retval=1
    # Waiting for the Policy Store service to be ready
    # Do not wait more than 30s, as it is expected to have store reachable. if not exit
    while true; do
        if ((i > STORE_AVAILABILITY_TIME_OUT)); then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - A timeout was reached (${STORE_AVAILABILITY_TIME_OUT} seconds), while waiting for the policy store service to be available"
            update_error_string "A timeout was reached (${STORE_AVAILABILITY_TIME_OUT} seconds), while waiting for the policy store service to be available"    
            entroy_check
            break
        fi

        if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
            RETCODE=($($PS_HOME/bin/smldapsetup status | grep -i "error:"))
            if [ $? -ne 0 ]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store Service is up and running"
                retval=0
                break
            else
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $RETCODE, trying again in ($i)..."
                ((i = i + 10))
                retval=1
                sleep 10
            fi
        fi
    done
    return "$retval"
}


wait_for_key_store_to_start()
{
    i=0
    retval=1
    # Waiting for the Key Store service to be ready
    while true; do
        if ((i > STORE_AVAILABILITY_TIME_OUT)); then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - A timeout was reached (${STORE_AVAILABILITY_TIME_OUT} seconds) while waiting for the key store service to be available"
            update_error_string "A timeout was reached (${STORE_AVAILABILITY_TIME_OUT} seconds) while waiting for the key store service to be available"  
            entroy_check
            break
        fi

        if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
            RETCODE=($($PS_HOME/bin/smldapsetup status -k1 | grep "Error:"))
            
            if [ $? -ne 0 ]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Key Store Service is up and running"
                retval=0
                break
            else
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $RETCODE, trying again in ($i)..."
                ((i = i + 10))
                sleep 10
                retval=1
            fi
        fi
    done
    return "$retval"
}


configure_scheme()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring SSO Policy Store Scheme"
    $PS_HOME/bin/smldapsetup ldgen -f/tmp/smldap.ldif 
    $PS_HOME/bin/smldapsetup ldmod -f/tmp/smldap.ldif 
    if [[ "$POLICY_STORE_LDAP_TYPE" = "ODS" ]]; then
        $PS_HOME/bin/smldapsetup ldmod -f$PS_HOME/xps/db/OracleDirectoryServer.ldif
    elif [[ "$POLICY_STORE_LDAP_TYPE" = "AD" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring SSO Policy Store Scheme for Active Directory"
        rootDN=$(grep "$LDIF_SCHEMA_DN" /tmp/smldap.ldif | gawk -F"$LDIF_SCHEMA_DN" '{print $2}' | tr -d '[:cntrl:]')
        cp "$PS_HOME/xps/db/ActiveDirectory.ldif" "/tmp/ActiveDirectory.ldif"
        sed -i "s|<RootDN>|${rootDN}|g" "/tmp/ActiveDirectory.ldif"
        $PS_HOME/bin/smldapsetup ldmod -f/tmp/ActiveDirectory.ldif
    elif [[ "$POLICY_STORE_LDAP_TYPE" = "ADLDS" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring SSO Policy Store Scheme for Active Directory Lightweight Directory Service"
        ADLDS_USERDN=$POLICY_STORE_USER_DN
        cp "$PS_HOME/xps/db/ADLDS.ldif" "/tmp/ADLDS.ldif"
        GUID=$(echo $ADLDS_USERDN | sed 's/CN={/\n/g' |tail -1| gawk -F} '{print $1}')
        sed -i "s|{guid}|{$GUID}|g" "/tmp/ADLDS.ldif"
        $PS_HOME/bin/smldapsetup ldmod -f/tmp/ADLDS.ldif
    fi
}


configure_key_scheme()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring SSO Key Store Scheme - Begin"
    #validate if SiteMinder dn exist.
    if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
        
        # identify siteminder schema, if already present it return 0 else 1
        ldap_schema_check "keystore" "$KEY_STORE_HOST" "$KEY_STORE_PORT" "$KEY_STORE_ROOT_DN" "$KEY_STORE_USER_DN" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_SSL_ENABLED" "$KEY_STORE_LDAP_TYPE"
        if [ "$?" == "0" ]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - SiteMinder schema already exist, hence initialized"
        else
            if [[ "$KEY_STORE_LDAP_TYPE" = "CADIR" ]]; then
                #if CADIR skip
                entroy_check
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: SiteMinder schema doesn't exist for CA Directory, exiting in 60 sec"
                update_error_string "Fatal error: SiteMinder schema doesn't exist for CA Directory, exiting in 60 sec"
                sleep 60
                exit 2
            else
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - SiteMinder DN doesn't exist, creating scheme for $KEY_STORE_LDAP_TYPE"
                if [[ "$KEY_STORE_LDAP_TYPE" = "ODS" ]] || [[ "$KEY_STORE_LDAP_TYPE" == "ADLDS" ]] || [[ "$KEY_STORE_LDAP_TYPE" == "AD" ]]; then
                    $PS_HOME/bin/smldapsetup ldgen -f/tmp/smkeyldap.ldif -k1
                    $PS_HOME/bin/smldapsetup ldmod -f/tmp/smkeyldap.ldif -k1
                    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key scheme created using ldgen and ldmod"         
                fi
            fi
        fi
            
    else
        if [[ "$KEY_STORE_TYPE" = "ODBC" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for key store $KEY_STORE_ODBC_TYPE schema creation"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="NO"
            if [[ "$KEY_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
                "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" \
                "1" "$PS_HOME/config/odbcssl/$KEY_STORE_SSL_TRUSTSTORE" \
                "$KEY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$KEY_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
                "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi
            # If database connection to key store fails, return code 99 will be returned
            # this is fatal error
            if [  $? -ne 0 ]; then
                entroy_check
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: schema creation failed for ODBC key store, exiting in 60 sec"
				update_error_string "Fatal error: schema creation failed for ODBC key store, exiting in 60 sec"
                sleep 60;
                exit 1
            fi
        fi
    fi
    
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring SSO Key Store Scheme - Completed"    
}
#this disables the registry entry of use default key store option.
disable_usedefault_keystore()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Disabling UseDefault option for ODBC and LDAP key store"   
    TOOLOPERATION="MODIFYSMREG"
    SMREGISTRY_SUBKEY="Use Default"
    SMREGISTRY_SUBKEY_VALUE="0x0"
    SMREGISTRY_SUBKEY_VALUE_TYPE="REG_DWORD"
    SMREGISTRY_KEY=""
    
    if [[ "$POLICY_STORE_TYPE" = "ODBC" ]]; then
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
        
        #disable Policy Store entries also opposite store type.
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapPolicyStore"
        SMREGISTRY_SUBKEY="Enabled"
        SMREGISTRY_SUBKEY_VALUE="0x0"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
         
    else
       if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
           
           #disable Policy Store entries also opposite store type.
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Default"
           SMREGISTRY_SUBKEY="Enabled"
           SMREGISTRY_SUBKEY_VALUE="0x0"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
       fi
    fi   
}

#enable key store.
enable_external_keystore()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Enabling option for $KEY_STORE_TYPE key store"  
    TOOLOPERATION="MODIFYSMREG"
    SMREGISTRY_SUBKEY="Enabled"
    SMREGISTRY_SUBKEY_VALUE="0x1"
    SMREGISTRY_SUBKEY_DIS_VALUE="0x0"
    SMREGISTRY_SUBKEY_VALUE_TYPE="REG_DWORD"
    SMREGISTRY_SUBKEY_NAMESPACE="KeyStoreProviderNamespace"
    SMREGISTRY_SUBKEY_NAMESPACE_VALUE="$KEY_STORE_TYPE:"    
            
    if [[ "$KEY_STORE_TYPE" = "ODBC" ]]; then
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
        
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_DIS_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
          
    else
       if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
            
           SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_DIS_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
           
          
       fi
    fi   
    
    #speacial case if Policy Store is ODBC 
    if [[ "$POLICY_STORE_TYPE" = "ODBC" ]]; then
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
        SMREGISTRY_SUBKEY="ProviderNamespace"
        SMREGISTRY_SUBKEY_VALUE="$KEY_STORE_TYPE:"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE "REG_SZ"
    fi
       
    #change the key store provider namespace
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\ObjectStore"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY_NAMESPACE $SMREGISTRY_SUBKEY_NAMESPACE_VALUE "REG_SZ"
}


upgrade_xdd_scheme()
{

    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting XPSDDinstall - upgrading xps schema"

    $PS_HOME/bin/XPSDDInstall $PS_HOME/xps/dd/SmMaster.xdd

    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - FinishedXPSDDInstall"

    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting import of default objects"

    $PS_HOME/bin/XPSImport $PS_HOME/db/smpolicy-containers.xml -npass
#generate xpsconfig input file testStoreVersion.txt to update 
# StoreVersion from policy store
cat << _EOF_ >/tmp/UpdateStoreVersion.txt
!Enter the option
SM
!Fetch StoreVersion paramter
StoreVersion
!change value
C
UPDATED_STORE_VERSION
!Quit from parameter section
Q
!Quit from smconfig tool
Q
_EOF_
   
   updatedStoreVersion=$(sed -n '/Name=StoreVersion/,+4 p' $PS_HOME/xps/dd/SmObjects.xdd |tail -1|sed s/=/\\n/g | tail -1| sed -e 's/^"//' -e 's/"$//')
   sed -i "s/UPDATED_STORE_VERSION/$updatedStoreVersion/g" /tmp/UpdateStoreVersion.txt
   
   $PS_HOME/bin/XPSConfig < /tmp/UpdateStoreVersion.txt 2>/tmp/xpsconfigerrUpdate.txt 1>/tmp/xpsconfigconsoleUpdate.txt
   echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Upgraded policy store version"
}

initialize_policy_store()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Initializing Policy Store Service"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Setting CA Single Sign-On super user password"
    if [[ $SUPERUSER_PASSWORD == "" ]]; then
        echo "[*][$(date +"%T")] - CA Single Sign-On super user password is empty"
        exit 1
    fi

    $PS_HOME/tmp/smreg -su $SUPERUSER_PASSWORD
    if [ $? -ne 0 ]; then
       entroy_check
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: failed to set siteminder super user password, exiting in 60 sec"
	   update_error_string "Fatal error: failed to set siteminder super user password, exiting in 60 sec"																									 
       sleep 60
       exit 1
    fi

    $PS_HOME/bin/XPSDDInstall $PS_HOME/xps/dd/SmMaster.xdd
    if [ $? -ne 0 ]; then
       entroy_check
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: failed to run XPSDDInstall, exiting in 60 sec"
       update_error_string "Fatal error: failed to run XPSDDInstall, exiting in 60 sec"																			   
       sleep 60
       exit 1
    fi 
    
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting import of default objects"

    $PS_HOME/bin/XPSImport $PS_HOME/db/smpolicy-containers.xml -npass
    if [ $? -ne 0 ]; then
       entroy_check
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: failed to run XPSImport for default objects, exiting in 60 sec"
       update_error_string "Fatal error: failed to run XPSImport for default objects, exiting in 60 sec" 
       sleep 60
       exit 1
    fi 

    # Import default CA certificates if CA_SM_IMPORT_DEFAULT_CA_CERTIFICATES is set to true
    if [[ "$CA_SM_IMPORT_DEFAULT_CA_CERTIFICATES" = "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Importing default CA certificates"
        $PS_HOME/bin/smkeytool.sh -importDefaultCACerts
    fi


if [ "$GENERATE_AG_OBJECTS" == "true" ]; then
#Create an admin User for proxyui in the Policy Store DSA
cat << _EOF_ > /tmp/ProxyUIAdmin.ldif
version: 1
dn: ou=administrators,o=sso
ou: administrators
objectClass: top
objectClass: organizationalUnit

dn: cn=admin,ou=administrators,o=sso
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
cn: admin
sn: sso
userPassword: $SUPERUSER_PASSWORD
_EOF_
        
        if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
            smldapmodify  -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -a -f /tmp/ProxyUIAdmin.ldif
            if [ $? -ne 0 ]; then
                 echo "[*][$(date +"%T")] - *ERROR* - Failed to create proxyui admin object in store"
            fi

        fi
        rm -fr /tmp/ProxyUIAdmin.ldif
    
        #Import objects that are required for the Secure Proxy deployment   
        filename="$BASE_IMPORT_FILES/ag_objects.xml"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Processing $filename"...
        sed -i 's|$AG_SHARED_SECRET|'"$AG_SHARED_SECRET"'|g' "$filename"   
        #Using the policy store service to access the DSA that stores the admin users        
        sed -i 's|$ADMIN_USER_DIRECTORY_SERVER|'"$ADMIN_USER_DIRECTORY_SERVICE:$POLICY_STORE_PORT"'|g' "$filename"        
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Using XPSImport to import $filename"...
        $PS_HOME/bin/XPSImport "$filename" -npass -fo
        if [ $? -ne 0 ]; then
             echo "[*][$(date +"%T")] - *ERROR* - Failed to import proxyui deployment object in the store"
        fi
    fi
        
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished import of default objects"
        

    # look for empty dir
    XMLFILECOUNT=`ls -l $CUSTOMER_IMPORT_FILES/*.xml 2>/tmp/lserr.txt | wc -l`
    if [ ${XMLFILECOUNT} -gt 0 ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Importing policy data found under $CUSTOMER_IMPORT_FILES"
        # Use XPSImport to import all the xml files in $CUSTOMER_IMPORT_FILES folder.
        for filename in $CUSTOMER_IMPORT_FILES/*.xml; do
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Processing $filename"...
            #sed -i 's|$DEPLOYMENT_FULLNAME|'"$DEPLOYMENT_FULLNAME"'|g' "$filename"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Using XPSImport to import $filename"...
            if [ -z "$IMPORT_PASSPHRASE" ]; then
                $PS_HOME/bin/XPSImport "$filename" -npass -fo
            else
                $PS_HOME/bin/XPSImport "$filename" -pass $IMPORT_PASSPHRASE -fo
            fi
        done
    else
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - No custom configuration files found to be imported [$CUSTOMER_IMPORT_FILES]"
    fi
    rm -rf /tmp/lserr.txt
    
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished import of Policy Store objects"
    
    # Currently, policy store and key store are embedded into same store.
    if [ $? -eq 0 ]; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store Service initialization completed"
    else
       entroy_check
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store Service initialization failed"
       update_error_string "Policy Store Service initialization failed"
       exit 1
    fi
}

wait_for_policy_store_to_be_initialized()
{
    i=0
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Waiting for the Policy Store Service to be initialized by the Admin Policy Server Service"
    while true; do
        if ((i > BOOTSTRAP_FETCH_TIME_OUT)); then
            entroy_check
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - A timeout was reached ($BOOTSTRAP_FETCH_TIME_OUT seconds) while waiting for the Policy Store Service to be initialized"
             update_error_string "A timeout was reached ($BOOTSTRAP_FETCH_TIME_OUT seconds) while waiting for the Policy Store Service to be initialized"
            exit 2
        fi
        readStoreInitObject
        retval=$?
        if [ "$retval" == 0 ]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store is initialized and ready"
            break
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Waiting for the Policy Store Service to be initialized ($i)..."
            ((i = i + 10))
            sleep 10
        fi
    done
}

policy_store_init_check()
{
    i=0
    while true; do
      readStoreInitObject
      retval=$?
      if [ "$retval" == 0 ]; then
          echo "[*][$(date +"%T")] - Policy Store is initialized and ready"
          break
      else
          echo "[*][$(date +"%T")] - Waiting for the Policy Store Service to be initialized ($i)..."
          ((i = i + 10))
          sleep 10
      fi
    done
    return "$retval"
}

# below logic will check sso init check objects,
# if not present will create on for already configured stores or old stores

check_for_policy_store_init_object()
{
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store initialized object check..."
    readStoreInitObject
    retval=$?
    if [ "$retval" == 0 ]; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store init object available"
       return "$retval"
    fi
    
    #not found, create it.
    writeStoreInitObject
}
#end of init store object check

add_certs_to_nss_db_for_ldapssl()
{
    SEARCH_LOC=$1
    IS_CERT_ROOTCA=$2
    for file in "$SEARCH_LOC"/*
    do
        if [ -d "$file" ]; then
            add_certs_to_nss_db_for_ldapssl "$file" $IS_CERT_ROOTCA
        else
            if [ -f $file ]; then
                if [ "$IS_CERT_ROOTCA" = true ] ; then
                   echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Adding root CA: $file"
                   $PS_HOME/bin/certutil -A -n "RootCA_$(basename $file)"  -t "$CERT_ATTRIBUTES_ROOTCA_CERT" -i "$file" -d $PS_HOME/config/ldapssl
                else
                   echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Adding server CA: $file"
                   $PS_HOME/bin/certutil -A -n "ServerCert_$(basename $file)"  -t "$CERT_ATTRIBUTES_SERVER_CERT" -i "$file" -d $PS_HOME/config/ldapssl
                fi
           
                # check the status of last executed command, which is certutil.
                if [ $? -ne 0 ]; then
                  echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Failed to import the certificate $file"
                  update_error_string "Failed to import the certificate $file"
                  exit 1
                fi
            fi            
        fi
    done
}

#Validate fips, Enc Key and superuser credentials. 
validate_policystore_settings()
{
    $PS_HOME/bin/XPSRegClient siteminder:$SUPERUSER_PASSWORD -adminui-setup
    if [ $? -ne 0 ]; then
        return 1
    else
        #do cleanup of file
        rm -fr $PS_HOME/bin/siteminder.XPSReg
        return 0
    fi
}


# This function display all the relevant env in container logs, based on feature enablement
print_env()
{
     TABSPACE="|__"
    #PS install home
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - *******************ENVIRONMENT*********************"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE PS_HOME=$PS_HOME"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CAPKIHOME=$CAPKIHOME"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE NETE_JRE_ROOT=$NETE_JRE_ROOT"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_FIPS140=$CA_SM_PS_FIPS140"
        
    echo " "
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE DATASTORES"
    #Policy Store
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE POLICY_STORE_TYPE=$POLICY_STORE_TYPE"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE PRIMARY"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_SERVICE=$POLICY_STORE_HOST"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_PORT=$POLICY_STORE_PORT"
    if [[ "$POLICY_STORE_TYPE" == "LDAP" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_LDAP_TYPE=$POLICY_STORE_LDAP_TYPE"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_ROOT_DN=$POLICY_STORE_ROOT_DN"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_USER_DN=$POLICY_STORE_USER_DN"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_SSL_ENABLED=$POLICY_STORE_SSL_ENABLED"
    else 
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_ODBC_TYPE=$POLICY_STORE_ODBC_TYPE"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_DSN=$POLICY_STORE_DSN"
        if [[ "$POLICY_STORE_ODBC_TYPE" == "MSSQL" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE DATABASE_NAME=$DATABASE_NAME"
        elif [[ "$POLICY_STORE_ODBC_TYPE" == "ORACLE" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE DATABASE_SERVICE_NAME=$DATABASE_SERVICE_NAME"
        elif [[ "$POLICY_STORE_ODBC_TYPE" == "MYSQL" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE DATABASE_NAME=$DATABASE_NAME"
        fi
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_USER=$POLICY_STORE_USER"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_SSL_ENABLED=$POLICY_STORE_SSL_ENABLED"
        if [[ "$POLICY_STORE_SSL_ENABLED" == "YES" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_SSL_TRUSTSTORE=$POLICY_STORE_SSL_TRUSTSTORE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE=$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE"
        fi
    fi
    #failover
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE FAILOVER"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_ADDITIONAL_HOSTS=$POLICY_STORE_ADDITIONAL_HOSTS"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE POLICY_STORE_ADDITIONAL_DSNS=$POLICY_STORE_ADDITIONAL_DSNS"
   
    #Key Store
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE KEY_STORE_EMBEDDED=$KEY_STORE_EMBEDDED"
    if [[ "$KEY_STORE_EMBEDDED" == "NO" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE KEY_STORE_TYPE=$KEY_STORE_TYPE"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE PRIMARY"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_SERVICE=$KEY_STORE_HOST"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_PORT=$KEY_STORE_PORT"
        
        if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_LDAP_TYPE=$KEY_STORE_LDAP_TYPE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_ROOT_DN=$KEY_STORE_ROOT_DN"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_USER_DN=$KEY_STORE_USER_DN"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_SSL_ENABLED=$KEY_STORE_SSL_ENABLED" 
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_ODBC_TYPE=$KEY_STORE_ODBC_TYPE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_DSN=$KEY_STORE_DSN"
            if [[ "$KEY_STORE_ODBC_TYPE" = "MSSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_DATABASE_NAME=$KEY_STORE_DATABASE_NAME"
            elif [[ "$KEY_STORE_ODBC_TYPE" = "ORACLE" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_DATABASE_SERVICE_NAME=$KEY_STORE_DATABASE_SERVICE_NAME"
            elif [[ "$KEY_STORE_ODBC_TYPE" = "MYSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_DATABASE_NAME=$KEY_STORE_DATABASE_NAME"
            fi
            
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_USER=$KEY_STORE_USER"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_SSL_ENABLED=$KEY_STORE_SSL_ENABLED"
            if [[ "$KEY_STORE_SSL_ENABLED" = "YES" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE KEY_STORE_SSL_TRUSTSTORE=$KEY_STORE_SSL_TRUSTSTORE"
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE KEY_STORE_SSL_HOSTNAMEINCERTIFICATE=$KEY_STORE_SSL_HOSTNAMEINCERTIFICATE"
            fi

        fi
        
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE FAILOVER"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_ADDITIONAL_HOSTS=$KEY_STORE_ADDITIONAL_HOSTS"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE KEY_STORE_ADDITIONAL_DSNS=$KEY_STORE_ADDITIONAL_DSNS"
    fi
    
    
    #Session Store
    if [[ "$CA_SM_PS_ENABLE_SESSION_STORE" == "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE SESSION_STORE_TYPE=$SESSION_STORE_TYPE"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE PRIMARY"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_HOST=$SESSION_STORE_HOST"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_PORT=$SESSION_STORE_PORT"
        
        if [[ "$SESSION_STORE_TYPE" = "LDAP" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_LDAP_TYPE=$SESSION_STORE_LDAP_TYPE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_ROOT_DN=$SESSION_STORE_ROOT_DN"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_USER_DN=$SESSION_STORE_USER_DN"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_SSL_ENABLED=$SESSION_STORE_SSL_ENABLED" 
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_ODBC_TYPE=$SESSION_STORE_ODBC_TYPE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_DSN=$SESSION_STORE_DSN"
            if [[ "$SESSION_STORE_ODBC_TYPE" = "MSSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_DATABASE_NAME=$SESSION_STORE_DATABASE_NAME"
            elif [[ "$SESSION_STORE_ODBC_TYPE" = "ORACLE" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_DATABASE_SERVICE_NAME=$SESSION_DATABASE_SERVICE_NAME"
            elif [[ "$SESSION_STORE_ODBC_TYPE" = "MYSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_DATABASE_NAME=$SESSION_STORE_DATABASE_NAME"
            fi
            
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_USER=$SESSION_STORE_USER"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_SSL_ENABLED=$SESSION_STORE_SSL_ENABLED"
            if [[ "$SESSION_STORE_SSL_ENABLED" == "YES" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_SSL_TRUSTSTORE=$SESSION_STORE_SSL_TRUSTSTORE"
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_SSL_HOSTNAMEINCERTIFICATE=$SESSION_STORE_SSL_HOSTNAMEINCERTIFICATE"
            fi

        fi
        
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE FAILOVER"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_ADDITIONAL_HOSTS=$SESSION_STORE_ADDITIONAL_HOSTS"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE SESSION_STORE_ADDITIONAL_DSNS=$SESSION_STORE_ADDITIONAL_DSNS"
        
   fi
    
    #Audit Store
    if [[ "$CA_SM_PS_ENABLE_AUDIT_STORE" = "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE AUDIT_STORE_TYPE=$AUDIT_STORE_TYPE"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE PRIMARY"
        if [[ "$AUDIT_STORE_TYPE" != "TEXT" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_HOST=$AUDIT_STORE_HOST"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_PORT=$AUDIT_STORE_PORT"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_ODBC_TYPE=$AUDIT_STORE_ODBC_TYPE"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_DSN=$AUDIT_STORE_DSN"
            if [[ "$AUDIT_STORE_ODBC_TYPE" = "MSSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_DATABASE_NAME=$AUDIT_STORE_DATABASE_NAME"
            elif [[ "$AUDIT_STORE_ODBC_TYPE" = "ORACLE" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_DATABASE_SERVICE_NAME=$AUDIT_DATABASE_SERVICE_NAME"
            elif [[ "$AUDIT_STORE_ODBC_TYPE" = "MYSQL" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_DATABASE_NAME=$AUDIT_STORE_DATABASE_NAME"
            fi
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_USER=$AUDIT_STORE_USER"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_SSL_ENABLED=$AUDIT_STORE_SSL_ENABLED"
            if [[ "$AUDIT_STORE_SSL_ENABLED" == "YES" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_SSL_TRUSTSTORE=$AUDIT_STORE_SSL_TRUSTSTORE"
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_SSL_HOSTNAMEINCERTIFICATE=$AUDIT_STORE_SSL_HOSTNAMEINCERTIFICATE"
            fi
            
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE FAILOVER"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_ADDITIONAL_HOSTS=$AUDIT_STORE_ADDITIONAL_HOSTS"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_STORE_ADDITIONAL_DSNS=$AUDIT_STORE_ADDITIONAL_DSNS"
        else
           echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_LOGGING_TEXTFILE=$SMAUDIT_LOGGING_TEXTFILE"
        fi
        
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_USER_ACTIVITY=$AUDIT_USER_ACTIVITY"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE AUDIT_ADMIN_STORE_ACTIVITY=$AUDIT_ADMIN_STORE_ACTIVITY"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE ADMIN_AUDITING=$ADMIN_AUDITING"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE ENABLE_AUTH_AUDITING=$ENABLE_AUTH_AUDITING"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE ENABLE_AZ_AUDITING=$ENABLE_AZ_AUDITING"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE ENABLE_ANON_AUTH_AUDITING=$ENABLE_ANON_AUTH_AUDITING"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE $TABSPACE ENABLE_AFFILIATE_AUDITING=$ENABLE_AFFILIATE_AUDITING"
        
        
    fi
    
    echo " "
    # IM Integration
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_ENABLE_CA_IDENITITY_MANAGER_INTEGRATION=$CA_SM_PS_ENABLE_CA_IDENITITY_MANAGER_INTEGRATION"
    
    if [ "$ROLE" != "admin" ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE POLICY_SERVER_INIT_TIMEOUT=$POLICY_SERVER_INIT_TIMEOUT"
        # Radius Server
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_ENABLE_RADIUS_SERVER=$CA_SM_PS_ENABLE_RADIUS_SERVER"
    fi
        
    # OVM
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_ENABLE_OVM=$CA_SM_PS_ENABLE_OVM"
    if [[ "$CA_SM_PS_ENABLE_OVM" == "YES" ]]; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE OVM_SERVICE_TOCONNECT=$OVM_SERVICE_TOCONNECT"
    fi
    
    #TraceConfig
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_TRACE_ENABLE=$CA_SM_PS_TRACE_ENABLE"
    if [[ "$CA_SM_PS_TRACE_ENABLE" == "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE SM_PS_TRACE_LOG_FILE=$SM_PS_TRACE_LOG_FILE"
    fi
    
    #Inmemory Tracing
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE CA_SM_PS_INMEMORY_TRACE_ENABLE=$CA_SM_PS_INMEMORY_TRACE_ENABLE" 
    if [[ "$CA_SM_PS_INMEMORY_TRACE_ENABLE" == "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE CA_SM_PS_INMEMORY_TRACE_OUTPUT=$CA_SM_PS_INMEMORY_TRACE_OUTPUT"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $TABSPACE $TABSPACE CA_SM_PS_INMEMORY_TRACE_FILE_SIZE=$CA_SM_PS_INMEMORY_TRACE_FILE_SIZE"
    fi 

    echo ""
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - *******************END ENVIRONMENT*********************"
    
}

ldap_schema_check()
{
    # objective is to read siteminder schema presence in ldap instance
    # validate the siteminder root DN as well.
    # input args store type:- policystore, keystore, sessionstore
    # ldap store details in below assignment order
    
    SMCOUNT="0"
    XPSCOUNT="0"
    SMDN="false"
    STORE_TYPE="$1"
    STORE_HOST="$2"
    STORE_PORT="$3"
    STORE_ROOTDN="$4"
    STORE_USERDN="$5"
    STORE_USRPWD="$6"
    STORE_SSL="$7"
    LDAP_TYPE="$8"
    # frame expected  siteminder root DN
    STORE_INIT_DN="$SITEMINDER_DN,$STORE_ROOTDN"
    
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Performing SiteMinder schema check on LDAP $STORE_TYPE"
    if [ "$STORE_SSL" == "YES" ]; then
        $PS_HOME/bin/ldapsearch -b "$STORE_INIT_DN" -h $STORE_HOST -p $STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$STORE_USERDN" -w $STORE_USRPWD -R -1 -s base "objectClass=*" description 2>/dev/null
        if [ "$?" == "0" ]; then
            SMDN="true"
        fi        

        if [[ "$LDAP_TYPE" == "CADIR" ]]; then
            SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -s base -b "cn=schema" "objectClass=*" objectClasses | grep sm | grep objectClasses | wc -l`
            XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -s base -b "cn=schema" "objectClass=*" objectClasses | grep xps | grep objectClasses | wc -l`
        else
            #AD and ADLDS
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - schema check on $LDAP_TYPE"
            SCHEMA_DN=""
            if [[ "$LDAP_TYPE" == "ADLDS" ]]; then
                PREFIX="CN={"
                GUID=$(echo $STORE_USERDN |gawk -FCN={ '{print $2'})
                SCHEMA_DN=$AD_SCHEMA_DN_PREFIX$PREFIX$GUID
                SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -P "$PS_HOME/config/ldapssl/cert9.db" -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep sm | wc -l`
                XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -P "$PS_HOME/config/ldapssl/cert9.db" -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep xps | wc -l`
           elif [[ "$LDAP_TYPE" == "AD" ]]; then
                $PS_HOME/bin/smldapsetup ldgen -f/tmp/smldap.ldif -k1
                rootDN=$(grep "$LDIF_SCHEMA_DN" /tmp/smldap.ldif | gawk -F"$LDIF_SCHEMA_DN" '{print $2}' | tr -d '[:cntrl:]')
                SCHEMA_DN=$AD_SCHEMA_DN_PREFIX$rootDN
                SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -P "$PS_HOME/config/ldapssl/cert9.db" -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep sm | wc -l`
                XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -P "$PS_HOME/config/ldapssl/cert9.db" -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep xps | wc -l`
           fi
        fi

    else
        $PS_HOME/bin/ldapsearch -b "$STORE_INIT_DN" -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -R -1 -s base "objectClass=*" description 2>/dev/null
        if [ "$?" == "0" ]; then
            SMDN="true"
        fi 

        if [[ "$LDAP_TYPE" == "CADIR" ]]; then
            SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -s base -b "cn=schema" "objectClass=*" objectClasses | grep sm | grep objectClasses | wc -l`
            XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -s base -b "cn=schema" "objectClass=*" objectClasses | grep xps | grep objectClasses | wc -l`
        else
            #AD and ADLDS
           echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - schema check on $LDAP_TYPE"
           SCHEMA_DN=""
           if [[ "$LDAP_TYPE" == "ADLDS" ]]; then
               PREFIX="CN={"
               GUID=$(echo $STORE_USERDN |gawk -FCN={ '{print $2'})
               SCHEMA_DN=$AD_SCHEMA_DN_PREFIX$PREFIX$GUID
               SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep sm | wc -l`
               XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep xps | wc -l`
           elif [[ "$LDAP_TYPE" == "AD" ]]; then
               $PS_HOME/bin/smldapsetup ldgen -f/tmp/smldap.ldif -k1
               rootDN=$(grep "$LDIF_SCHEMA_DN" /tmp/smldap.ldif | gawk -F"$LDIF_SCHEMA_DN" '{print $2}' | tr -d '[:cntrl:]')
               SCHEMA_DN=$AD_SCHEMA_DN_PREFIX$rootDN
               SMCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep sm | wc -l`
               XPSCOUNT=`$PS_HOME/bin/ldapsearch -x -h $STORE_HOST -p $STORE_PORT -D "$STORE_USERDN" -w $STORE_USRPWD -s sub -b "$SCHEMA_DN" "objectClass=classSchema" dn | grep xps | wc -l`
           fi
        fi
    fi
    
    #If session store, its ok no need of SiteMinder DN
    if [ "$STORE_TYPE" != "sessionstore" ]; then 
        if [ "$SMDN" == "false" ]; then
           #return fail
           return 1
        fi
    fi
   
    
    # check the occurrence
    # There has to be 38 sm & 4 xps class schema require for policy store and key store.
    # For session store only sm 44 class is needed, 6 more than SM.
    if [ "$SMCOUNT" -ge "$TOTAL_SM_CLASS_COUNT" ]; then 
        if [ "$STORE_TYPE" == "sessionstore" ]; then 
            
            if [ "$SMCOUNT" -ge "$TOTAL_SM_SS_CLASS_COUNT" ]; then
                #return success
                return 0
            else 
                return 1
            fi 
        else
            if [ "$STORE_TYPE" == "keystore" ]; then
                #return success
                return 0
            fi

            if [ "$XPSCOUNT" -ge "$TOTAL_XPS_CLASS_COUNT" ]; then
                #return success
                return 0
            else 
                #return fail
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - XPS scheme class count: $XPSCOUNT"
                return 1
            fi
        fi
    else
        #return fail
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - SM scheme class count: $SMCOUNT"
        return 1
    fi
}

add_default_mandatory_objects()
{
     # Use XPSImport to import all the xml files in $BASE_IMPORT_FILES folder.
    EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES="<StringValue>EXTERNAL_POLICYSERVER_SERVICE_NAME1,44441,44442,44443</StringValue>"

    if [ ! -z "$EXTERNAL_POLICYSERVER_SERVICE_NAME1" ]; then
        EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES="<StringValue>$EXTERNAL_POLICYSERVER_SERVICE_NAME1,$PS_ACCT_PORT,$PS_AUTHN_PORT,$PS_AUTHZ_PORT</StringValue>"
        if [ ! -z "$EXTERNAL_POLICYSERVER_SERVICE_NAME2" ]; then
            EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES="$EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES \\n<StringValue>$EXTERNAL_POLICYSERVER_SERVICE_NAME2,$PS_ACCT_PORT,$PS_AUTHN_PORT,$PS_AUTHZ_PORT</StringValue>"
        fi
    fi

    # search for HCO "localhost-psprobe-container" xid: 21-00020224-365a-1cd9-ac5a-3b81c0a80000
    nPsProbeObjInStore=0
    if [[ "$POLICY_STORE_TYPE" = "LDAP" ]] ; then
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
            $PS_HOME/bin/ldapsearch -x -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$XID_HCO_PSPROBE" 2>/dev/null >> /tmp/hcoprobe.txt
        else
            $PS_HOME/bin/ldapsearch -x -h "$POLICY_STORE_HOST" -p "$POLICY_STORE_PORT" -D "$POLICY_STORE_USER_DN" -w "$POLICY_STORE_USER_PASSWORD" -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$XID_HCO_PSPROBE" 2>/dev/null >> /tmp/hcoprobe.txt
        fi

        nTombStoneObj=$(cat /tmp/hcoprobe.txt | grep "xpsTombstone:" | wc -l)
        nObjInStore=$(cat /tmp/hcoprobe.txt | grep "dn: xpsNumber=" | wc -l)
        if [[ "$nObjInStore" -gt "$nTombStoneObj" ]]; then
            nPsProbeObjInStore=1
        fi
        rm -fr /tmp/hcoprobe.txt
    else
        #ODBC smconfigtool logic will be added here
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for checking psprobe object"
        TOOLOPERATION="EXECUTE_SQL_QUERY"
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "CHECK_PSPROBE_OBJ" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
        else
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "CHECK_PSPROBE_OBJ" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME"
        fi

        if [ $? -eq 97 ]; then
            nPsProbeObjInStore=1
        fi
    fi

    if [ $nPsProbeObjInStore -ne 0 ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - xpsGUID=$XID_HCO_PSPROBE object found"
    else
        filename="$BASE_IMPORT_FILES/smps_objects.xml"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Processing $filename"...
        sed -i 's|$POLICY_SERVER_SERVICE|'"$POLICY_SERVER_SERVICE"'|g' "$filename"
        sed -i 's|$EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES|'"$EXTERNAL_POLICYSERVER_SERVICE_NAME_ENTRIES"'|g' "$filename"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Using XPSImport to import $filename"...
        $PS_HOME/bin/XPSImport "$filename" -npass -fo
        if [ $? -ne 0 ]; then
             echo "[*][$(date +"%T")] - *ERROR* - Failed to create hco object for probe."
             update_error_string "*ERROR* - Failed to create hco object for probe."
        fi
    fi

}

writeStoreInitObject()
{
    if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
       ## Creating an indicator object in the store to mark the completion of store initialization for LDAP store
    if [[ "$POLICY_STORE_LDAP_TYPE" != "AD" && "$POLICY_STORE_LDAP_TYPE" != "ADLDS" ]]; then
cat << _EOF_ >/tmp/SSOInitialized.ldif
version: 1
dn: $POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR_DN
objectClass: organizationalUnit
objectClass: top
ou: SSOInitialized
description: SSO container init object
_EOF_
    else
cat << _EOF_ >/tmp/SSOInitialized.ldif
version: 1
dn: $POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR_DN
objectClass: organizationalUnit
objectClass: top
description: SSO container init object
_EOF_
    fi
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
           $PS_HOME/bin/smldapmodify  -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -a -f /tmp/SSOInitialized.ldif
        else
           $PS_HOME/bin/smldapmodify  -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -a -f /tmp/SSOInitialized.ldif
        fi
        if [ $? -ne 0 ]; then
             echo "[*][$(date +"%T")] - *ERROR* - Failed to create policy store init object"
             update_error_string "*ERROR* - Failed to create policy store init object"
        fi
        #clean up ldif file
        rm -fr /tmp/SSOInitialized.ldif
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store init created"
    
    else
        # checking for indicator object in the store to mark the completion of store initialization for ODBC Store
        TOOLOPERATION="EXECUTE_SQL_QUERY"
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "STORE_INIT_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
        else
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "STORE_INIT_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" 
        fi
        if [ $? -eq 99 ]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store init object available"
            retval=0
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store init created"
        fi

    fi
    
}

readStoreInitObject()
{
    retval=1
    if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running ldapsearch for checking store init complete indicator for LDAP stores"
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
           $PS_HOME/bin/ldapsearch -b "$POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR_DN" -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -R -1 -s base "objectClass=*" description 2>/dev/null
        else
           $PS_HOME/bin/ldapsearch -b "$POLICY_STORE_INITIALIZATION_COMPLETE_INDICATOR_DN" -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -R -1 -s base "objectClass=*" description 2>/dev/null
        fi
      
        if [ $? -eq 0 ]; then
            retval=0
        fi
    else
        # checking for indicator object in the store to mark the completion of store initialization for ODBC Store
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for checking store init complete indicator for ODBC stores"
        TOOLOPERATION="EXECUTE_SQL_QUERY"
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "STORE_INIT_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
        else
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "STORE_INIT_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" 
        fi
        if [ $? -eq 99 ]; then
            retval=0
        fi

    fi
    return "$retval"
    
}


updateAgentConnMaxLifetime()
{
#generate xpsconfig input file to update AgentConnectionMaxLifetime.txt
# as global setting in store
cat << _EOF_ >/tmp/AgentConnectionMaxLifetime.txt
!Enter the option
SM
!Fetch AgentConnectionMaxLifetime paramter
AgentConnectionMaxLifetime
!change value
C
G
$AGENT_CONN_MAX_LIFETIME
!Quit from parameter section
Q
!Quit from SM product menu
Q
!Quit from xpsconfig tool menu
Q
_EOF_

   $PS_HOME/bin/XPSConfig < /tmp/AgentConnectionMaxLifetime.txt 2>/tmp/xpsconfigerr-agent.txt 1>/tmp/xpsconfigconsole-agent.txt
   echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - updated AgentConnectionMaxLifetime xps paramter "
}

# Archive troubleshot data and upload to cloud storage
archive_and_send_data() {
if [[ ! -z "${TROUBLESHOOT_DATA_STORAGE_TYPE}" ]]; then
  cd /opt/CA/siteminder
  cp -pr /opt/CA/siteminder/log /opt/CA/siteminder/siteminder-data/
  if [[ "${TROUBLESHOOT_DATA_STORAGE_TYPE}" == "awsS3" ]]; then

    # This is done to please aws cli to have access to home folder
    export HOME=/tmp

    $PS_HOME/bin/smSecretProcessor.sh -decryptk8sSingleSecrets AWS_ACCESS_KEY_ID $TROUBLESHOOT_DATA_AWS_ACCESS_KEY_ID $MASTERKEYSEED 1>/tmp/runTool.sh
    keyID=$(cat /tmp/runTool.sh | gawk -FAWS_ACCESS_KEY_ID= '{print $2}' | tr -d ''\''"')
    export AWS_ACCESS_KEY_ID=$keyID

    $PS_HOME/bin/smSecretProcessor.sh -decryptk8sSingleSecrets AWS_SECRET_ACCESS_KEY $TROUBLESHOOT_DATA_AWS_SECRET_ACCESS_KEY $MASTERKEYSEED 1>/tmp/runTool.sh
    acKey=$(cat /tmp/runTool.sh | gawk -FAWS_SECRET_ACCESS_KEY= '{print $2}' | tr -d ''\''"')
    export AWS_SECRET_ACCESS_KEY=$acKey
    export AWS_DEFAULT_REGION=$TROUBLESHOOT_DATA_AWS_DEFAULT_REGION

																 
    dt=$(date '+%Y-%m-%d')
    now=$(date +%s)
    fileName=siteminder-maintenanace-info-$HOSTNAME-$dt-$now.tar.gz
  
    tar -czvf $fileName siteminder-data 
    aws s3 cp $fileName $AWS_BUCKET_NAME
    echo "Maintenance operation related data upload completed"
	
	unset HOME

  elif [[ "${TROUBLESHOOT_DATA_STORAGE_TYPE}" == "azureFileShares" ]]; then
    $PS_HOME/bin/smSecretProcessor.sh -decryptk8sSingleSecrets TROUBLESHOOT_DATA_AZURE_SAS_TOKEN $TROUBLESHOOT_DATA_AZURE_SAS_TOKEN $MASTERKEYSEED 1>/tmp/runTool.sh
    sasToken=$(cat /tmp/runTool.sh | gawk -FTROUBLESHOOT_DATA_AZURE_SAS_TOKEN= '{print $2}' | tr -d ''\''"')
    export TROUBLESHOOT_DATA_AZURE_SAS_TOKEN=$sasToken

    dt=$(date '+%Y-%m-%d')
    now=$(date +%s)
    fileName=siteminder-maintenanace-info-$HOSTNAME-$dt-$now.tar.gz

    tar -czvf $fileName siteminder-data
    
    fileShareUrl=$AZURE_FILE_ENDPOINT$AZURE_FILESHARE_NAME$AZURE_SHARE_DIR_PATH$fileName$TROUBLESHOOT_DATA_AZURE_SAS_TOKEN
    azcopy cp "$fileName" $fileShareUrl 
    echo "Maintenance operation related data upload completed"
 
  fi
fi

}


## Main

FILE_NAME=`basename "$0"`
echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $FILE_NAME: **starting**"

echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Parsing policy store service details entered"
parse_store_host_strings "${POLICY_STORE_SERVICE}" "${POLICY_STORE_TYPE}"
declare -ag pstore
pstore=(${array[@]})
echo ${pstore[*]}

# If this is the Admin Policy Server service, concatanate to get the full DNS hostname needed to register with the Policy Store in the same pod
# IF this is the Policy Server service, point at the Policy Store Service to register with any Policy Store instance
if [[ ${POLICY_STORE_SERVICE} == *.svc.cluster.local ]]; then
    export POLICY_STORE_HOST=${HOSTNAME}.${POLICY_STORE_SERVICE}
else
    export POLICY_STORE_HOST=${STORE_HOST}
fi
POLICY_STORE_PORT=${STORE_PORT}
if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
    POLICY_STORE_ADDITIONAL_HOSTS=$ADDITIONAL_HOST_STRINGS
fi

if [[ "$POLICY_STORE_TYPE" = "ODBC" ]]; then
    parse_store_host_strings "${POLICY_STORE_DSN}" "${POLICY_STORE_TYPE}"
    pstore=(${array[@]})
    echo ${pstore[*]}
    POLICY_STORE_DSN=${STORE_HOST}
    if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
        POLICY_STORE_ADDITIONAL_DSNS="$ADDITIONAL_HOST_STRINGS"
    fi
fi

#key store
parse_store_host_strings "${KEY_STORE_SERVICE}" "${KEY_STORE_TYPE}"
declare -ag kstore
kstore=(${array[@]})
echo ${kstore[*]}

if [[ ${KEY_STORE_SERVICE} == *.svc.cluster.local ]]; then
    export KEY_STORE_HOST=${HOSTNAME}.${KEY_STORE_SERVICE}
else
    export KEY_STORE_HOST=${STORE_HOST}
fi

KEY_STORE_PORT=${STORE_PORT}
if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
    KEY_STORE_ADDITIONAL_HOSTS=$ADDITIONAL_HOST_STRINGS
fi

if [[ "$KEY_STORE_TYPE" = "ODBC" ]]; then
    parse_store_host_strings "${KEY_STORE_DSN}" "${KEY_STORE_TYPE}"
    kstore=(${array[@]})
    echo ${kstore[*]}
    KEY_STORE_DSN=${STORE_HOST}
    if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
        KEY_STORE_ADDITIONAL_DSNS="$ADDITIONAL_HOST_STRINGS"
    fi
fi

#session store
declare -ag sstore
if [[ "$CA_SM_PS_ENABLE_SESSION_STORE" = "YES" ]]; then

        parse_store_host_strings "${SESSION_STORE_SERVER}" "${SESSION_STORE_TYPE}"
        sstore=(${array[@]})
        echo ${sstore[*]}
        export SESSION_STORE_HOST=${STORE_HOST}
        export SESSION_STORE_PORT=${STORE_PORT}
        
        if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
            SESSION_STORE_ADDITIONAL_HOSTS=$ADDITIONAL_HOST_STRINGS
        fi

        if [[ "$SESSION_STORE_TYPE" = "ODBC" ]]; then
            parse_store_host_strings "${SESSION_STORE_DSN}" "${SESSION_STORE_TYPE}"
            sstore=(${array[@]})
            echo ${sstore[*]}
            SESSION_STORE_DSN=${STORE_HOST}
            if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
                SESSION_STORE_ADDITIONAL_DSNS="$ADDITIONAL_HOST_STRINGS"
            fi
        fi
fi

#audit store
declare -ag audstore
if [[ "$CA_SM_PS_ENABLE_AUDIT_STORE" = "YES" ]]; then
        if [[ "$AUDIT_STORE_TYPE" = "ODBC" ]]; then
            
            parse_store_host_strings "${AUDIT_STORE_SERVER}" "${AUDIT_STORE_TYPE}"
            export AUDIT_STORE_HOST=${STORE_HOST}
            export AUDIT_STORE_PORT=${STORE_PORT}

            parse_store_host_strings "${AUDIT_STORE_DSN}" "${AUDIT_STORE_TYPE}"
            audstore=(${array[@]})
            echo ${audstore[*]}
            AUDIT_STORE_DSN=${STORE_HOST}
            if [[ "$ADDITIONAL_HOST_STRINGS" != "" ]]; then
               AUDIT_STORE_ADDITIONAL_DSNS="$ADDITIONAL_HOST_STRINGS"
            fi
        fi
fi



# Copy SmCommand to a shared location to allow querying for the ps status (only do this once for admin or policy server, whichever runs first on the node)
COMMON_TOOLS=/configuration/common
if [ ! -d $COMMON_TOOLS ]; then
    mkdir ${COMMON_TOOLS}
    cp /opt/CA/siteminder/bin/SmCommand ${COMMON_TOOLS}/
    cp /opt/CA/siteminder/lib/libsmi18n.so ${COMMON_TOOLS}/
    cp /opt/CA/siteminder/lib/libicu* ${COMMON_TOOLS}/
    cp /opt/CA/siteminder/lib/libSmXlate.so ${COMMON_TOOLS}/
    mkdir ${COMMON_TOOLS}/resources
    cp /opt/CA/siteminder/resources/gclcommand* ${COMMON_TOOLS}/resources/
fi

#Check if sm.registry is suplied vi config retriver. if 
#already exist, reset to default to avoid PS unexpected behavior/failure.
SMREGFILE="${PS_HOME}/registry/sm.registry"

defaultValues

#enableTags


#Let Entropy check run first and warn if needed! 
entroy_check


echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting smreg operations"
$PS_HOME/tmp/smreg LoadRegKeys "$PS_HOME" "" "EN"

###PRINT ENV VARIABLE
print_env

echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configure Policy Server service to point at the Policy Store service"



$PS_HOME/tmp/smreg TestCryptoConfig "$POLICY_STORE_ENCRYPTION_KEY"  "0" "" "" ""
$PS_HOME/tmp/smreg SetCryptoConfig "$POLICY_STORE_ENCRYPTION_KEY"  "0" "" "" ""
$PS_HOME/tmp/smreg $DASH_PIN$ LoadInstallKey -123
echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished smreg LoadInstallKeys"
if [ "$ROLE" == "admin" ]; then
    $PS_HOME/tmp/smreg -key $POLICY_STORE_ENCRYPTION_KEY
fi
echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished executing smreg"




#Create Netscape Certificate Database, as it common for any LDAP SSL Connection
#and import all the available Root and Server certificates 

echo "$LDAP_SSL_NSSDB_PASSWORD" > /tmp/nssdbinfo
# Create NSS DB, if it doesn't exist.
if [ ! -f $PS_HOME/config/ldapssl/cert9.db ]; then
    if [ ! -d $PS_HOME/config/ldapssl ]; then
        mkdir $PS_HOME/config/ldapssl
    fi
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Creating NSS DB for LDAP SSL support"
    $PS_HOME/bin/certutil -N -d $PS_HOME/config/ldapssl -f /tmp/nssdbinfo
    rm -f /tmp/nssdbinfo
fi   

#Add path to cert9.db file for Policy Server to use, as this is common for all type
#of store key store, sesstion store, user store. Hence its good add path here itself
TOOLOPERATION="MODIFYSMREG"
SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapPolicyStore"
SMREGISTRY_SUBKEY="CertDbPath"
SMREGISTRY_SUBKEY_VALUE="$PS_HOME/config/ldapssl/cert9.db"
SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
$PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE


# Add Root certificates by parsing the config/ldapssl/rootcerts
SEARCH_FOLDER="$PS_HOME/config/ldapssl/rootcerts"
add_certs_to_nss_db_for_ldapssl $SEARCH_FOLDER true

# Add Server certificates by parsing the config/ldapssl/servercerts
SEARCH_FOLDER="$PS_HOME/config/ldapssl/servercerts"
add_certs_to_nss_db_for_ldapssl $SEARCH_FOLDER false

# Check if system.odbc.ini file is present or not if not then create it
# to avoid file exceptino durin DSN creation
if [ ! -f $PS_HOME/db/system_odbc.ini ]; then
   touch $PS_HOME/db/system_odbc.ini
fi

#Reset InstallPath in system_odbc.ini file. This is require when failover and fallback scenario is there else
#driver throws error in smps.log 
MATCH_ODBC=`grep  "^\[ODBC\]" $PS_HOME/db/system_odbc.ini`
if [ $? -eq 0 ]; then
    # [ODBC] entry found
    MATCH_INSTDIR=`grep -i "^InstallDir=" $PS_HOME/db/system_odbc.ini`
    if [ $? -eq 0 ]; then
        #InstallDir found, Updating InstallDir
        sed -i "/InstallDir=/c\InstallDir=$PS_HOME/odbc" $PS_HOME/db/system_odbc.ini
    else
        # InstallDir not found, Adding InstallDir
        sed -i "/^\[ODBC\]/a InstallDir=$PS_HOME/odbc" $PS_HOME/db/system_odbc.ini
    fi
else
    # [ODBC] not found, Adding both paraemter"
    echo ' ' >> $PS_HOME/db/system_odbc.ini
    echo '[ODBC]' >> $PS_HOME/db/system_odbc.ini
    echo "InstallDir=$PS_HOME/odbc" >> $PS_HOME/db/system_odbc.ini
fi

#If Policy Store & Key Store is same

if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smldapsetup switch"
    $PS_HOME/bin/smldapsetup switch
    retval=1
    for i in "${pstore[@]}"
    do
        case $i in
        (*:*) STORE_HOST=${i%:*} STORE_PORT=${i##*:};;
        (*)   STORE_HOST=$i      STORE_PORT="";;
        esac
        POLICY_STORE_HOST=$STORE_HOST
        POLICY_STORE_PORT=$STORE_PORT

    if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
        # Run smldapsetup with SSL settings
        # SSL enabled 
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting smldapsetup reg (SSL)"
        $PS_HOME/bin/smldapsetup reg -h$POLICY_STORE_HOST -p$POLICY_STORE_PORT "-d$POLICY_STORE_USER_DN" -w$POLICY_STORE_USER_PASSWORD -r$POLICY_STORE_ROOT_DN -ssl"1" 
    else
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting smldapsetup reg"
        $PS_HOME/bin/smldapsetup reg -h$POLICY_STORE_HOST -p$POLICY_STORE_PORT "-d$POLICY_STORE_USER_DN" -w$POLICY_STORE_USER_PASSWORD -r$POLICY_STORE_ROOT_DN -ssl"0" 
    fi

    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished smldapsetup reg"
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Checking if the Policy Store Service is up and running..."
    wait_for_policy_store_to_start
    retval=$?
    if [[ $retval == 0 ]] ; then
      echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - policy store connection successful"
      break
    else
      echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - policy store connection failed"
    fi
    done
    # end the for loop for pstore array
    if [[ $retval == 1 ]] ; then
      echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - policy store connection cannot be established, container init failed"
      exit 1
    fi

cat << _EOF_ >/tmp/storeInitDetails.sh
export POLICY_STORE_HOST=$POLICY_STORE_HOST
export POLICY_STORE_PORT=$POLICY_STORE_PORT
_EOF_

    if [[ "$POLICY_STORE_ADDITIONAL_HOSTS" != "" ]]; then
        echo "[*][$(date +"%T")] - Policy store failover is enabled. Configuring policystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapPolicyStore"
        SMREGISTRY_SUBKEY="Server"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${pstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE $i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")] - Finished policystore failover configuration"
    fi
else
   #expecting this is primary server and check for DSN info in system_odbc.ini
   dsnfound=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
   if [[ $dsnfound == 0 ]] ; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $POLICY_STORE_DSN not found in system_odbc.ini"
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Policy Store DSN Creation"
       TOOLOPERATION="SMDBCONFIG"
       CREATEONLY_DSN="YES"
       CONNECTION_CHECK="NO"
       # during this phase store connection check will happen and only DSN will be created.
       if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
           "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
       else
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
           "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
       fi

       #incase of failure report and stop executing further as this fatal.
       if [ $? -ne 0 ]; then
          echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Error ODBC configuration failed for policy store, exiting in 60 sec"
          update_error_string "Error ODBC configuration failed for policy store, exiting in 60 sec"
          sleep 60
          exit 1
       fi
   else
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $POLICY_STORE_DSN found in system_odbc.ini"
   fi

   #fetch the details from system_odbc.ini file
   # and perform connection check
   for i in "${pstore[@]}"
   do
     POLICY_STORE_DSN="$i"
     hostStringDSN=""
     portStringDSN=""
     dbName="Database"
     dbServiceName="ServiceName"
     dbTrustStore="TrustStore"
     dbTrustStorePwd="TrustStorePassword"
     dbTrustStorePath="$PS_HOME/config/odbcssl/"
     POLICY_STORE_SSL_TRUSTSTORE=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStore} | gawk -F= '{print $2}' | gawk -F${dbTrustStorePath} '{print $2}' | head -1)
     POLICY_STORE_SSL_TRUSTPWD=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStorePwd} | gawk -F= '{print $2}' | head -1)

     case "$POLICY_STORE_ODBC_TYPE" in
         "MSSQL")
         hostStringDSN="Address"
         POLICY_STORE_HOST=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $1}')
         POLICY_STORE_PORT=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $2}')
         DATABASE_NAME=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | gawk -F= '{print $2}')
         ;;
         "ORACLE"| "MYSQL")
         hostStringDSN="HostName"
         portStringDSN="PortNumber"
         POLICY_STORE_HOST=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}')
         POLICY_STORE_PORT=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${portStringDSN} | gawk -F= '{print $2}')
         if [[ $POLICY_STORE_ODBC_TYPE == "MYSQL" ]]; then
             DATABASE_NAME=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | head -1 |gawk -F= '{print $2}')
         else
             DATABASE_SERVICE_NAME=$(sed -n "/\[$POLICY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbServiceName} | gawk -F= '{print $2}')
         fi
         ;;
     esac

     echo "[*][$(date +"%T")] - Running smconfigtool for Policy Store connection check with DSN: $POLICY_STORE_DSN"
     TOOLOPERATION="SMDBCONFIG"
     CREATEONLY_DSN="NO"
     CONNECTION_CHECK="YES"
     check="false"
     # during this phase store connection check will happen and only DSN will be created.
     if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
       $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
       "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
     else
       $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
       "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
     fi

     #incase of failure report and stop executing further as this fatal.
     if [ $? -ne 0 ]; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Error ODBC configuration failed for policy store with DSN $POLICY_STORE_DSN"
       sleep 1
     else
       check="true"
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - ODBC Policy Store connection is successful with DSN $POLICY_STORE_DSN"
       break
     fi
   done
   if [[ $check == false ]] ; then
     echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Error ODBC configuration failed for policy store"
     update_error_string "Error ODBC configuration failed for policy store"
     exit 1
   fi

cat << _EOF_ >/tmp/storeInitDetails.sh
export POLICY_STORE_HOST=$POLICY_STORE_HOST
export POLICY_STORE_PORT=$POLICY_STORE_PORT
export POLICY_STORE_DSN=$POLICY_STORE_DSN
export DATABASE_NAME=$DATABASE_NAME
export DATABASE_SERVICE_NAME=$DATABASE_SERVICE_NAME
export POLICY_STORE_SSL_TRUSTSTORE=$POLICY_STORE_SSL_TRUSTSTORE
export POLICY_STORE_SSL_TRUSTPWD=$POLICY_STORE_SSL_TRUSTPWD
_EOF_

    if [[ "$POLICY_STORE_ADDITIONAL_DSNS" != "" ]]; then
        echo "[*][$(date +"%T")] - Policy store failover is enabled. Configuring policystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Default"
        SMREGISTRY_SUBKEY="Data Source"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${pstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE,$i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "$SMREGISTRY_SUBKEY" "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")] - Finished policystore failover configuration"
    fi
fi

#Enable Advanced Password Services in Policy Server
if [ "$ROLE" != "admin" ]; then
    if [[ "$CA_SM_PS_USE_APS" = "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Enabling Advanced Password Services in Policy Server"
        mv "$PS_HOME/lib/libsmaps_rename4aps.so" "$PS_HOME/lib/libsmaps.so"
    fi
fi


echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Server service configuring as $ROLE"

# Checking if this instance of Policy Server should initialize the policy store
# only casso-admin-0 is allowed to do.
isInitializer=false
ordinal=99
if [[ "$ROLE" = "admin" && "$POLICY_SERVER_INIT_ENABLED" = "YES" ]]; then
    # Generate server-id from pod ordinal index.
    [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
    ordinal=${BASH_REMATCH[1]}
    if [ $ordinal -eq 0 ]; then
        isInitializer=true
    fi
fi

if [ "$isInitializer" == "true" ]; then
    nInitStore=0
    # Checking whether the schema is of the right version by checking the existence of a certain attribute
    if [[ "$POLICY_STORE_TYPE" = "ODBC" ]] ; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for checking for xps schema for ODBC stores"
        TOOLOPERATION="EXECUTE_SQL_QUERY"
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "SOTRE_SCHEMA_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
        else
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "SOTRE_SCHEMA_CHECK" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
            "$DATABASE_NAME" "$DATABASE_SERVICE_NAME"
        fi

        if [ $? -eq 98 ]; then
            nInitStore=1
        fi
    else
        if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
           nInitStore=$($PS_HOME/bin/ldapsearch -x -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$POLICY_STORE_VERIFICATION_ATTRIBUTE" 2>/dev/null |  grep "dn: xpsNumber="|wc -l)
        else
            nInitStore=$($PS_HOME/bin/ldapsearch -x -h "$POLICY_STORE_HOST" -p "$POLICY_STORE_PORT" -D "$POLICY_STORE_USER_DN" -w "$POLICY_STORE_USER_PASSWORD" -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$POLICY_STORE_VERIFICATION_ATTRIBUTE" 2>/dev/null |  grep "dn: xpsNumber="|wc -l)
        fi

        if [ $nInitStore -ne 0 ]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $POLICY_STORE_VERIFICATION_ATTRIBUTE schema object found, Policy Store is initialized"
        fi
    fi

    if [ $nInitStore -eq 0 ]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store is not initialized or is not running an updated schema"
        if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
            # identify siteminder schema, if already present it return 0 else 1
            ldap_schema_check "policystore" "$POLICY_STORE_HOST" "$POLICY_STORE_PORT" "$POLICY_STORE_ROOT_DN" "$POLICY_STORE_USER_DN" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_SSL_ENABLED" "$POLICY_STORE_LDAP_TYPE"
            
            if [ "$?" !=  "0" ]; then
               if [[ "$POLICY_STORE_LDAP_TYPE" = "ODS" || "$POLICY_STORE_LDAP_TYPE" = "AD" || "$POLICY_STORE_LDAP_TYPE" = "ADLDS" ]]; then
                  # TBD as ODS not supporting
                  configure_scheme 
               elif [[ "$POLICY_STORE_LDAP_TYPE" = "CADIR" ]]; then
                  # schema not present, in CA Directory can't proceed.
                  echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Siteminder schema not found in CA Directory instance unable to proceed, exiting in 60 sec"
                  update_error_string "Siteminder schema not found in CA Directory instance unable to proceed, exiting in 60 sec"
                  sleep 60
                  exit 1;
               fi
            fi
  
        fi

        if [[ "$POLICY_STORE_TYPE" = "ODBC" ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for schema creation"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="NO"
            if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" $POLICY_STORE_ODBC_TYPE $CREATEONLY_DSN $POLICY_STORE_PORT "$POLICY_STORE_DSN" "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi
            # If database connection to policy store fails, return code 99 will be returned
            if [ $? -eq $POLICY_STORE_ODBC_CON_FAILURE ]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: schema creation failed for ODBC policy store, exiting in 60 sec"
                update_error_string "Fatal error: schema creation failed for ODBC policy store, exiting in 60 sec"
                sleep 60;
                exit 1
            fi
        fi

        # schema is intact, we can proceed importing dictionary and default objects.
        #create xps schema objects
        initialize_policy_store
    else
      if [[ $ENABLE_XPS_SCHEMA_UPGRADE = "YES" ]]; then
#generate xpsconfig input file testStoreVersion.txt to fetch
# StoreVersion from policy store
cat << _EOF_ >/tmp/testStoreVersion.txt
!Enter the option
SM
!Quit from parameter section
Q
!Quit from smconfig tool
Q
_EOF_
        StoreVersion=""
        if [[ "$POLICY_STORE_TYPE" = "ODBC" ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for fetching store version"
            TOOLOPERATION="EXECUTE_SQL_QUERY"
            if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "FETCH_STORE_VERSION" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
                "$DATABASE_NAME" "$DATABASE_SERVICE_NAME" "1" "$PS_HOME/config/odbcssl/$POLICY_STORE_SSL_TRUSTSTORE" "$POLICY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$POLICY_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "POLICY_STORE" "FETCH_STORE_VERSION" $POLICY_STORE_ODBC_TYPE $POLICY_STORE_PORT "$POLICY_STORE_USER" "$POLICY_STORE_USER_PASSWORD" "$POLICY_STORE_HOST" \
                "$DATABASE_NAME" "$DATABASE_SERVICE_NAME"
            fi

            if [ $? -eq 96 ]; then
                StoreVersion=$(cat /tmp/storeversioncheck.txt | sed -n -e '/[[:digit:]]/p')
            fi

        else
            if [[ "$POLICY_STORE_SSL_ENABLED" = "YES" ]]; then
                StoreVersion=$($PS_HOME/bin/ldapsearch -x -h $POLICY_STORE_HOST -p $POLICY_STORE_PORT -P "$PS_HOME/config/ldapssl/cert9.db" -D "$POLICY_STORE_USER_DN" -w $POLICY_STORE_USER_PASSWORD -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$XDD_VERSION" 2>/dev/null | sed -n -e '/^xpsProperty:.*\[1\]S=.*$/p'| gawk -F= '{print $2}' | sed -n -e '/[[:digit:]]/p')
            else
                StoreVersion=$($PS_HOME/bin/ldapsearch -x -h "$POLICY_STORE_HOST" -p "$POLICY_STORE_PORT" -D "$POLICY_STORE_USER_DN" -w "$POLICY_STORE_USER_PASSWORD" -b "$POLICY_STORE_ROOT_DN" -R -s sub "xpsGUID=$XDD_VERSION" 2>/dev/null | sed -n -e '/^xpsProperty:.*\[1\]S=.*$/p'| gawk -F= '{print $2}' | sed -n -e '/[[:digit:]]/p')
            fi
        fi

        xddStoreVersion=$(sed -n '/Name=StoreVersion/,+4 p' $PS_HOME/xps/dd/SmObjects.xdd |tail -1|sed s/=/\\n/g | tail -1| sed -e 's/^"//' -e 's/"$//')
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - StoreVersion from policy store: $StoreVersion"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - xddStoreVersion from SmObjects.xdd file: $xddStoreVersion"
        upgrade_scheme=false
        if [ -z "$StoreVersion" ]; then
           echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Store version not present in policy store"
           upgrade_scheme=true
        elif [ -n "$xddStoreVersion" ]; then
           IFS='.' read -ra currentVersion <<< "$StoreVersion"
           IFS='.' read -ra nextVersion <<< "$xddStoreVersion"
           # 0 - Major Version, 1 - Minor Version, 2 - Service Pack, 3 - Build Number
           if [ "${nextVersion[0]}" -gt "${currentVersion[0]}" ]; then
              upgrade_scheme=true
           elif [ "${nextVersion[0]}" -eq "${currentVersion[0]}" ]; then
               if [ "${nextVersion[1]}" -gt "${currentVersion[1]}" ]; then
                  upgrade_scheme=true
               elif [ "${nextVersion[1]}" -eq "${currentVersion[1]}" ]; then
                   if [ "${nextVersion[2]}" -gt "${currentVersion[2]}" ]; then
                      upgrade_scheme=true
                   elif [ "${nextVersion[2]}" -eq "${currentVersion[2]}"  ]; then
                       if [ "${nextVersion[3]}" -gt "${currentVersion[3]}" ]; then
                          upgrade_scheme=true
                       fi
                   fi
               fi
           fi

           #validating existin store settings before proceeding for upgrade
           #If we are, means store is used/written during using container deployment
           validate_policystore_settings
           if [ "$?" !=  "0" ]; then
               upgrade_scheme=false
               echo "[*][$(date +"%T")] - *ERROR* - Mismatch in existing policy store settings, ignoring schema upgrade."
               update_error_string "*ERROR* - Mismatch in existing policy store settings, ignoring schema upgrade."
           fi

        fi


       #upgrade xdd schema
        if [ "$upgrade_scheme" = true ] ; then
           echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - upgrading policy store xps scheme: $xddStoreVersion"
           upgrade_xdd_scheme
        fi
      fi
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store is initialized and running with the latest schema"

    fi
    rm -rf /tmp/replay.cmd

    # Creating audit store schema and adding audit store connection to policy server
    # First will check schema if not present, we will create. Any connectino failure will be handled via schema 
    # creation. Create DSN and proceed further if schema creation failed.
    if [[ "$CA_SM_PS_ENABLE_AUDIT_STORE" = "YES" ]]; then
        if [[ "$AUDIT_STORE_TYPE" = "ODBC" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Audit store schema creation"
          #expecting this is primary server and check for DSN info in system_odbc.ini
          dsnfound=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
          if [[ $dsnfound == 0 ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $AUDIT_STORE_DSN not found in system_odbc.ini"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Audit Store DSN Creation"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="YES"
            if [[ "$AUDIT_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
                "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$AUDIT_STORE_SSL_TRUSTSTORE" "$AUDIT_STORE_SSL_HOSTNAMEINCERTIFICATE" "$AUDIT_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
                "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi         
            # If database connection to audit store fails, return code 99 will be returned
            if [ $? -ne 0 ]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN creation failed for audit store ODBC store, as non-fatal error proceeding container configuration"
            fi
          else
            echo "[*][$(date +"%T")] - DSN $AUDIT_STORE_DSN found in system_odbc.ini"
          fi

        #fetch the details from system_odbc.ini file
        # and perform connection check and schema creation
        for i in "${audstore[@]}"
        do
          AUDIT_STORE_DSN="$i"
          hostStringDSN=""
          portStringDSN="PortNumber"
          dbName="Database"
          dbServiceName="ServiceName"
          dbTrustStore="TrustStore"
          dbTrustStorePwd="TrustStorePassword"
          dbTrustStorePath="$PS_HOME/config/odbcssl/"
          AUDIT_STORE_SSL_TRUSTSTORE=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStore} | gawk -F= '{print $2}' | gawk -F${dbTrustStorePath} '{print $2}' | head -1)
          AUDIT_STORE_SSL_TRUSTPWD=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStorePwd} | gawk -F= '{print $2}' | head -1)

        case "$AUDIT_STORE_ODBC_TYPE" in
          "MSSQL")
          hostStringDSN="Address"
          AUDIT_STORE_HOST=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $1}')
          AUDIT_STORE_PORT=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $2}')
          AUDIT_STORE_DATABASE_NAME=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | gawk -F= '{print $2}')
          ;;
          "ORACLE" | "MYSQL")
          hostStringDSN="HostName"
          AUDIT_STORE_HOST=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}')
          AUDIT_STORE_PORT=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${portStringDSN} | gawk -F= '{print $2}')
          if [[ "$AUDIT_STORE_ODBC_TYPE" == "MYSQL" ]]; then
             AUDIT_STORE_DATABASE_NAME=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | head -1 | gawk -F= '{print $2}')
          else
             AUDIT_DATABASE_SERVICE_NAME=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbServiceName} | gawk -F= '{print $2}')
          fi
          ;;
        esac

        echo "[*][$(date +"%T")] - Running smconfigtool for Audit Store connection check with DSN: $AUDIT_STORE_DSN"

        TOOLOPERATION="SMDBCONFIG"
        CONNECTION_CHECK="NO"
        CREATEONLY_DSN="NO"
        if [[ "$AUDIT_STORE_SSL_ENABLED" = "YES" ]]; then
           $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
           "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
           "$PS_HOME/config/odbcssl/$AUDIT_STORE_SSL_TRUSTSTORE" "$AUDIT_STORE_SSL_HOSTNAMEINCERTIFICATE" "$AUDIT_STORE_SSL_TRUSTPWD"
        else
          $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
          "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
        fi         
        # If database connection to audit store fails, return code 99 will be returned
        if [ $? -ne 0 ]; then
          echo "[*][$(date +"%T")] - Schema creation failed for audit store ODBC store, as non-fatal error proceeding container configuration"
        else
          echo "[*][$(date +"%T")] - Schema creation success for audit store ODBC store"
          break;
        fi
      done
        # Setting Registry entries related audit log options
        TOOLOPERATION="SMREGCONFIG"
        SMAUDIT_USERACTIVITY="$SMAUDIT_USERACTIVITY$AUDIT_USER_ACTIVITY"
        SMAUDIT_ADMIN_STORE_ACTIVITY="$SMAUDIT_ADMIN_STORE_ACTIVITY$AUDIT_ADMIN_STORE_ACTIVITY"
        SMADMIN_AUDITING="$SMADMIN_AUDITING$ADMIN_AUDITING"
        SMAUTH_AUDITING="$SMAUTH_AUDITING$ENABLE_AUTH_AUDITING"
        SMAZ_AUDITING="$SMAZ_AUDITING$ENABLE_AZ_AUDITING"
        SMAUTH_ANON_AUDITING="$SMAUTH_ANON_AUDITING$ENABLE_ANON_AUTH_AUDITING"
        SMAZ_ANON_AUDITING="$SMAZ_ANON_AUDITING$ENABLE_ANON_AZ_AUDITING"
        SMAFFILIATE_AUDITING="$SMAFFILIATE_AUDITING$ENABLE_AFFILIATE_AUDITING"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMAUDIT_USERACTIVITY $SMAUDIT_ADMIN_STORE_ACTIVITY $SMADMIN_AUDITING $SMAUTH_AUDITING $SMAZ_AUDITING $SMAUTH_ANON_AUDITING $SMAZ_ANON_AUDITING $SMAFFILIATE_AUDITING

        elif [[ "$AUDIT_STORE_TYPE" = "TEXT" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for smacess audit log enabling"
            TOOLOPERATION="SMREGCONFIG"
            SMAUDIT_FILEPATH="$SMAUDIT_FILEPATH$SMAUDIT_LOGGING_TEXTFILE"
            SMAUDIT_USERACTIVITY="$SMAUDIT_USERACTIVITY$AUDIT_USER_ACTIVITY"
            SMAUDIT_ADMIN_STORE_ACTIVITY="$SMAUDIT_ADMIN_STORE_ACTIVITY$AUDIT_ADMIN_STORE_ACTIVITY"
            SMADMIN_AUDITING="$SMADMIN_AUDITING$ADMIN_AUDITING"
            SMAUTH_AUDITING="$SMAUTH_AUDITING$ENABLE_AUTH_AUDITING"
            SMAZ_AUDITING="$SMAZ_AUDITING$ENABLE_AZ_AUDITING"
            SMAUTH_ANON_AUDITING="$SMAUTH_ANON_AUDITING$ENABLE_ANON_AUTH_AUDITING"
            SMAZ_ANON_AUDITING="$SMAZ_ANON_AUDITING$ENABLE_ANON_AZ_AUDITING"
            SMAFFILIATE_AUDITING="$SMAFFILIATE_AUDITING$ENABLE_AFFILIATE_AUDITING"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMAUDIT_FILEPATH $SMAUDIT_USERACTIVITY $SMAUDIT_ADMIN_STORE_ACTIVITY $SMADMIN_AUDITING $SMAUTH_AUDITING $SMAZ_AUDITING $SMAUTH_ANON_AUDITING $SMAZ_ANON_AUDITING $SMAFFILIATE_AUDITING
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Audit store type not supported - $AUDIT_STORE_TYPE"
        fi
    fi

    # Creating session store schema and adding session store connection to policy server
    if [[ "$CA_SM_PS_ENABLE_SESSION_STORE" = "YES" ]]; then
        
        if [[ "$SESSION_STORE_TYPE" = "ODBC" ]]; then
          #expecting this is primary server and check for DSN info in system_odbc.ini
          dsnfound=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
          if [[ $dsnfound == 0 ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $SESSION_STORE_DSN not found in system_odbc.ini"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Session Store DSN Creation"
            TOOLOPERATION="SMDBCONFIG"
            CREATEONLY_DSN="YES"
            CONNECTION_CHECK="NO"

            if [[ "$SESSION_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN $SESSION_STORE_PORT \
                "$SESSION_STORE_DSN" "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$SESSION_STORE_SSL_TRUSTSTORE" "$SESSION_STORE_SSL_HOSTNAMEINCERTIFICATE" "$SESSION_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN $SESSION_STORE_PORT \
                "$SESSION_STORE_DSN" "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi
            # If database connection to session store fails, return code 99 will be returned
            if [ $? -ne 0 ]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN creation failed for session store ODBC store, as non-fatal error proceeding configuration"
            fi 
          fi 


          #fetch the details from system_odbc.ini file
          # and perform connection check
          for i in "${sstore[@]}"
          do
            SESSION_STORE_DSN="$i"
            hostStringDSN=""
            portStringDSN="PortNumber"
            dbName="Database"
            dbServiceName="ServiceName"
            dbTrustStore="TrustStore"
            dbTrustStorePwd="TrustStorePassword"
            dbTrustStorePath="$PS_HOME/config/odbcssl/"
            SESSION_STORE_SSL_TRUSTSTORE=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStore} | gawk -F= '{print $2}' | gawk -F${dbTrustStorePath} '{print $2}' | head -1)
            SESSION_STORE_SSL_TRUSTPWD=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStorePwd} | gawk -F= '{print $2}' | head -1)

            case "$SESSION_STORE_ODBC_TYPE" in
            "MSSQL")
            hostStringDSN="Address"
            SESSION_STORE_HOST=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $1}')
            SESSION_STORE_PORT=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $2}')
            SESSION_STORE_DATABASE_NAME=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | gawk -F= '{print $2}')
            ;;
            "ORACLE" | "MYSQL")
            hostStringDSN="HostName"
            SESSION_STORE_HOST=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}')
            SESSION_STORE_PORT=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${portStringDSN} | gawk -F= '{print $2}')
            if [[ "$SESSION_STORE_ODBC_TYPE" == "MYSQL" ]]; then
                SESSION_STORE_DATABASE_NAME=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | head -1 |gawk -F= '{print $2}')
            else
                SESSION_DATABASE_SERVICE_NAME=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbServiceName} | gawk -F= '{print $2}')
            fi
            ;;
          esac

            echo "[*][$(date +"%T")] - Running smconfigtool for Session Store schema creation with DSN: $SESSION_STORE_DSN"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="NO"
            check="false"
            if [[ "$SESSION_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN $SESSION_STORE_PORT \
                "$SESSION_STORE_DSN" "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$SESSION_STORE_SSL_TRUSTSTORE" "$SESSION_STORE_SSL_HOSTNAMEINCERTIFICATE" "$SESSION_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN $SESSION_STORE_PORT \
                "$SESSION_STORE_DSN" "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi

            # If database connection to session store fails, return code 99 will be returned
            if [ $? -ne 0 ]; then
                echo "[*][$(date +"%T")] - Schema creation failed for session store ODBC store, as non-fatal error proceeding DSN creation"
                check="false"
            else
                check="true"
                echo "[*][$(date +"%T")] - ODBC Session Store configuration is successful with DSN $SESSION_STORE_DSN"
                break
            fi
           done
 
           if [[ $check == false ]] ; then
               echo "[*][$(date +"%T")] - Error ODBC configuration failed for session store"
               update_error_string "Error ODBC configuration failed for session store"
           fi
          
        else
            if [[ "$SESSION_STORE_TYPE" = "LDAP" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for LDAP Session store configuration"
                
                # identify siteminder schema, if already present it return 0 else 1
                ldap_schema_check "sessionstore" "$SESSION_STORE_HOST" "$SESSION_STORE_PORT" "$SESSION_STORE_ROOT_DN" "$SESSION_STORE_USER_DN" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_SSL_ENABLED" "CADIR"
                if [ "$?" != "0" ]; then
                    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Schema not present for session store CA Directory, as non-fatal error proceeding with configuration"
                fi 

                TOOLOPERATION="SESSION_LDAP"
                SESSION_STORE_IPADDRESS="${SESSION_STORE_HOST}:${SESSION_STORE_PORT}"
                if [[ "$SESSION_STORE_SSL_ENABLED" = "YES" ]]; then
                    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "TRUE" $SESSION_STORE_IPADDRESS "$SESSION_STORE_ROOT_DN" "$SESSION_STORE_USER_DN" "$SESSION_STORE_USER_PASSWORD" "true"
                else
                    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "TRUE" $SESSION_STORE_IPADDRESS "$SESSION_STORE_ROOT_DN" "$SESSION_STORE_USER_DN" "$SESSION_STORE_USER_PASSWORD" "false"
                fi
            fi
        fi  
    fi

    # Creating required schema in policy store for IDM Objects (used for SSO-IDM integration)
    if [[ "$CA_SM_PS_ENABLE_CA_IDENITITY_MANAGER_INTEGRATION" = "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Integration of CA Single Sign-On with CA Identity Manager is enabled. Checking for IDM schema and updating if not available"
        echo r> /tmp/idmreplay.cmd
        echo $IDM_SCHEMA_VERIFICATION_ATTRIBUTE>> /tmp/idmreplay.cmd
        $PS_HOME/bin/XPSDictionary < /tmp/idmreplay.cmd 2>/dev/null | grep "$IDM_XPSDICTIONARY_MATCH_STRING"
        if [ $? -ne 0 ]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store does not contain updated CA Identity Manager objects schema"
            #create xps schema for IDM objects
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Starting XPSDDinstall for IdmSmObjects"
            $PS_HOME/bin/XPSDDInstall $PS_HOME/xps/dd/IdmSmObjects.xdd
            if [ $? -ne 0 ]; then
                 echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - *ERROR* - Failed to create schema for IDM objects"
            else
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished XPSDDInstall for IdmSmObjects"
            fi
            
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Store running with the latest CA Identity Manager objects schema"
        fi
        rm -rf /tmp/idmreplay.cmd
    fi

else

    # as policy-server-init container will be doining all initlization
    # admin-pod-0 should be enabled for agentkey generation. which is by default enabled.
    # so registry update should be skiped for admin-pod-0 pod.
    isAdminPod0=false
    podordinal=99
    if [[ "$ROLE" = "admin" && "$CONTAINER_LABEL" = "policy-server" ]]; then
        # Generate server-id from pod ordinal index.
        [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
        podordinal=${BASH_REMATCH[1]}
        if [ $podordinal -eq 0 ]; then
            isAdminPod0=true
        fi
    fi

    # deployment pod init container
    if [[ "$ROLE" = "policyserver-init-check" ]]; then
       policy_store_init_check
       exit 0
    else
       # This block belongs Worker PS
       # Policy Server will wait for the Policy Store to be initialized by the Admin Policy Server
       if [[ "$isAdminPod0" == "false" ]] ; then
           wait_for_policy_store_to_be_initialized
       fi
    fi


    if [[ "$isAdminPod0" == "false" ]] ; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool to update EnableKeyGeneration registry "
        TOOLOPERATION="SMREGCONFIG"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMENABLEKEYGENERATION
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Server in $HOSTNAME POD is set not to generate agent keys"
    elif [[ "$isAdminPod0" == "true"  &&  "$ENABLE_AGENT_KEY_GENERATION" == "false" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool to update EnableKeyGeneration registry "
        TOOLOPERATION="SMREGCONFIG"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMENABLEKEYGENERATION
        echo "[*][$(date +"%T")] - Policy Server in $HOSTNAME POD is set not to generate agent keys"
    fi

    if [[ "$isAdminPod0" == "true" ]] ; then
        # only For ADMIN POD-0 update the 'EnableKeyUpdate' registry
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool to update EnableKeyUpdate registry "
        TOOLOPERATION="SMREGCONFIG"
        if [[ "$ENABLE_KEY_UPDATE" == "true" ]] ; then
          SMENABLEKEYUPDATE=${SMENABLEKEYUPDATEPREFIX}"YES"
        else
          SMENABLEKEYUPDATE=${SMENABLEKEYUPDATEPREFIX}"NO"
        fi

        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMENABLEKEYUPDATE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy Server in $HOSTNAME POD, EnableKeyUpdate registry updated"
    fi

    # Creating audit store dsn and adding audit store connection to policy server
    if [[ "$CA_SM_PS_ENABLE_AUDIT_STORE" = "YES" ]]; then
        if [[ "$AUDIT_STORE_TYPE" = "ODBC" ]]; then
          #expecting this is primary server and check for DSN info in system_odbc.ini
          dsnfound=$(sed -n "/\[$AUDIT_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
          if [[ $dsnfound == 0 ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $AUDIT_STORE_DSN not found in system_odbc.ini"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Audit Store DSN Creation"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="YES"
            if [[ "$AUDIT_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
                "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$AUDIT_STORE_SSL_TRUSTSTORE" "$AUDIT_STORE_SSL_HOSTNAMEINCERTIFICATE" "$AUDIT_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "AUDIT_STORE" $AUDIT_STORE_ODBC_TYPE $CREATEONLY_DSN $AUDIT_STORE_PORT "$AUDIT_STORE_DSN" "$AUDIT_STORE_USER" "$AUDIT_STORE_USER_PASSWORD" "$AUDIT_STORE_HOST" \
                "$AUDIT_STORE_DATABASE_NAME" "$AUDIT_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi
          fi
            # Setting Registry entries related audit log options
            TOOLOPERATION="SMREGCONFIG"
            SMAUDIT_USERACTIVITY="$SMAUDIT_USERACTIVITY$AUDIT_USER_ACTIVITY"
            SMAUDIT_ADMIN_STORE_ACTIVITY="$SMAUDIT_ADMIN_STORE_ACTIVITY$AUDIT_ADMIN_STORE_ACTIVITY"
            SMADMIN_AUDITING="$SMADMIN_AUDITING$ADMIN_AUDITING"
            SMAUTH_AUDITING="$SMAUTH_AUDITING$ENABLE_AUTH_AUDITING"
            SMAZ_AUDITING="$SMAZ_AUDITING$ENABLE_AZ_AUDITING"
            SMAUTH_ANON_AUDITING="$SMAUTH_ANON_AUDITING$ENABLE_ANON_AUTH_AUDITING"
            SMAZ_ANON_AUDITING="$SMAZ_ANON_AUDITING$ENABLE_ANON_AZ_AUDITING"
            SMAFFILIATE_AUDITING="$SMAFFILIATE_AUDITING$ENABLE_AFFILIATE_AUDITING"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMAUDIT_USERACTIVITY $SMAUDIT_ADMIN_STORE_ACTIVITY $SMADMIN_AUDITING $SMAUTH_AUDITING $SMAZ_AUDITING $SMAUTH_ANON_AUDITING $SMAZ_ANON_AUDITING $SMAFFILIATE_AUDITING

        elif [[ "$AUDIT_STORE_TYPE" = "TEXT" ]]; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for smacess audit log enabling"
            TOOLOPERATION="SMREGCONFIG"
            SMAUDIT_FILEPATH="$SMAUDIT_FILEPATH$SMAUDIT_LOGGING_TEXTFILE"
            SMAUDIT_USERACTIVITY="$SMAUDIT_USERACTIVITY$AUDIT_USER_ACTIVITY"
            SMAUDIT_ADMIN_STORE_ACTIVITY="$SMAUDIT_ADMIN_STORE_ACTIVITY$AUDIT_ADMIN_STORE_ACTIVITY"
            SMADMIN_AUDITING="$SMADMIN_AUDITING$ADMIN_AUDITING"
            SMAUTH_AUDITING="$SMAUTH_AUDITING$ENABLE_AUTH_AUDITING"
            SMAZ_AUDITING="$SMAZ_AUDITING$ENABLE_AZ_AUDITING"
            SMAUTH_ANON_AUDITING="$SMAUTH_ANON_AUDITING$ENABLE_ANON_AUTH_AUDITING"
            SMAZ_ANON_AUDITING="$SMAZ_ANON_AUDITING$ENABLE_ANON_AZ_AUDITING"
            SMAFFILIATE_AUDITING="$SMAFFILIATE_AUDITING$ENABLE_AFFILIATE_AUDITING"
            $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMAUDIT_FILEPATH $SMAUDIT_USERACTIVITY $SMAUDIT_ADMIN_STORE_ACTIVITY $SMADMIN_AUDITING $SMAUTH_AUDITING $SMAZ_AUDITING $SMAUTH_ANON_AUDITING $SMAZ_ANON_AUDITING $SMAFFILIATE_AUDITING
        else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Audit store type not supported - $AUDIT_STORE_TYPE"
        fi
    fi

    # Creating session store dsn and adding session store connection to policy server
    if [[ "$CA_SM_PS_ENABLE_SESSION_STORE" = "YES" ]]; then

        if [[ "$SESSION_STORE_TYPE" = "ODBC" ]]; then
          #expecting this is primary server and check for DSN info in system_odbc.ini
          dsnfound=$(sed -n "/\[$SESSION_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
          if [[ $dsnfound == 0 ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $SESSION_STORE_DSN not found in system_odbc.ini"
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Session store DSN creation"
            TOOLOPERATION="SMDBCONFIG"
            CONNECTION_CHECK="NO"
            CREATEONLY_DSN="YES"
            if [[ "$SESSION_STORE_SSL_ENABLED" = "YES" ]]; then
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN \
                $SESSION_STORE_PORT "$SESSION_STORE_DSN" \
                "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" "1" \
                "$PS_HOME/config/odbcssl/$SESSION_STORE_SSL_TRUSTSTORE" "$SESSION_STORE_SSL_HOSTNAMEINCERTIFICATE" "$SESSION_STORE_SSL_TRUSTPWD"
            else
                $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "SESSION_STORE" $SESSION_STORE_ODBC_TYPE $CREATEONLY_DSN \
                $SESSION_STORE_PORT "$SESSION_STORE_DSN" \
                "$SESSION_STORE_USER" "$SESSION_STORE_USER_PASSWORD" "$SESSION_STORE_HOST" \
                "$SESSION_STORE_DATABASE_NAME" "$SESSION_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
            fi
          fi
        else
            if [[ "$SESSION_STORE_TYPE" = "LDAP" ]]; then
                echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for LDAP Session store configuration"
                TOOLOPERATION="SESSION_LDAP"
                SESSION_STORE_IPADDRESS="${SESSION_STORE_HOST}:${SESSION_STORE_PORT}"
                if [[ "$SESSION_STORE_SSL_ENABLED" = "YES" ]]; then
                    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "TRUE" $SESSION_STORE_IPADDRESS "$SESSION_STORE_ROOT_DN" "$SESSION_STORE_USER_DN" "$SESSION_STORE_USER_PASSWORD" "true"
                else
                    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "TRUE" $SESSION_STORE_IPADDRESS "$SESSION_STORE_ROOT_DN" "$SESSION_STORE_USER_DN" "$SESSION_STORE_USER_PASSWORD" "false"
                fi
            fi
        fi
    fi
fi

# Check for policy store Failover support
if [[ "$POLICY_STORE_TYPE" = "LDAP" ]]; then
    if [[ "$POLICY_STORE_ADDITIONAL_HOSTS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy store failover is enabled. Configuring policystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapPolicyStore"
        SMREGISTRY_SUBKEY="Server"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${pstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE $i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished policystore failover configuration"
    fi
else
    if [[ "$POLICY_STORE_ADDITIONAL_DSNS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Policy store failover is enabled. Configuring policystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Default"
        SMREGISTRY_SUBKEY="Data Source"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${pstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE,$i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "$SMREGISTRY_SUBKEY" "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished policystore failover configuration"
    fi
fi



#Configure External Key Store if Enabled
if [[ "$KEY_STORE_EMBEDDED" = "NO" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - External Key Store option selected, disable Use Default option"
    #disable defult key store first
    disable_usedefault_keystore
    #enable external key store
    enable_external_keystore
    if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring LDAP Key Store settings"


        ksretval=1
        for i in "${kstore[@]}"
        do
          case $i in
          (*:*) STORE_HOST=${i%:*} STORE_PORT=${i##*:};;
          (*)   STORE_HOST=$i      STORE_PORT="";;
          esac
          KEY_STORE_HOST=$STORE_HOST
          KEY_STORE_PORT=$STORE_PORT

          echo "$PS_HOME/bin/smldapsetup reg -h$KEY_STORE_HOST -p$KEY_STORE_PORT -d$KEY_STORE_USER_DN -w**** -r$KEY_STORE_ROOT_DN -ssl$KEY_STORE_SSL_ENABLED -k1 "
        
          if [[ "$KEY_STORE_SSL_ENABLED" = "YES" ]]; then
             # configure key store ldap with SSL
             $PS_HOME/bin/smldapsetup reg -h$KEY_STORE_HOST -p$KEY_STORE_PORT "-d$KEY_STORE_USER_DN" -w$KEY_STORE_USER_PASSWORD -r$KEY_STORE_ROOT_DN -ssl"1" -k1
          else
             $PS_HOME/bin/smldapsetup reg -h$KEY_STORE_HOST -p$KEY_STORE_PORT "-d$KEY_STORE_USER_DN" -w$KEY_STORE_USER_PASSWORD -r$KEY_STORE_ROOT_DN -ssl"0" -k1
          fi
        
          echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished smldapsetup reg for key store"
          echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Checking if the Key Store Service is up and running..."
          wait_for_key_store_to_start
          ksretval=$?
          if [[ $ksretval == 0 ]] ; then
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key store connection successful"
            break
          else
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key store connection failed"
          fi
        done
      # end the for loop for kstore array
      if [[ $ksretval == 1 ]] ; then
          echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key store connection cannot be established, container init failed"
          exit 1
      fi
   else
     #expecting this is primary server and check for DSN info in system_odbc.ini
     echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Configuring ODBC Key Store"
     dsnfound=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini |wc -l)
     if [[ $dsnfound == 0 ]] ; then
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - DSN $KEY_STORE_DSN not found in system_odbc.ini"
       echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for Key Store DSN Creation"
       TOOLOPERATION="SMDBCONFIG"
       CREATEONLY_DSN="YES"
       CONNECTION_CHECK="NO"
       # during this phase store connection check will happen and only DSN will be created.
        if [[ "$KEY_STORE_SSL_ENABLED" = "YES" ]]; then
             $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
             "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" \
             "1" "$PS_HOME/config/odbcssl/$KEY_STORE_SSL_TRUSTSTORE" \
             "$KEY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$KEY_STORE_SSL_TRUSTPWD"
        else
            $PS_HOME/bin/smconfigtool.sh  $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
            "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
        fi

        #incase of failure report and stop executing further as this fatal.
        if [ $? -ne 0 ]; then
            entroy_check
            echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Fatal error: ODBC configuration failed for external key store, exiting in 60 sec"
            update_error_string "Fatal error: ODBC configuration failed for external key store, exiting in 60 sec"
            sleep 60
            exit 1
        fi
     else
       echo "[*][$(date +"%T")] - Key Store DSN: $KEY_STORE_DSN found in system_odbc.ini"
     fi

   #fetch the details from system_odbc.ini file
   # and perform connection check
   for i in "${kstore[@]}"
   do
     KEY_STORE_DSN="$i"
     hostStringDSN=""
     portStringDSN="PortNumber"
     dbName="Database"
     dbServiceName="ServiceName"
     dbTrustStore="TrustStore"
     dbTrustStorePwd="TrustStorePassword"
     dbTrustStorePath="$PS_HOME/config/odbcssl/"
     KEY_STORE_SSL_TRUSTSTORE=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStore} | gawk -F= '{print $2}' | gawk -F${dbTrustStorePath} '{print $2}' | head -1)
     KEY_STORE_SSL_TRUSTPWD=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbTrustStorePwd} | gawk -F= '{print $2}' | head -1)

     case "$KEY_STORE_ODBC_TYPE" in
         "MSSQL") hostStringDSN="Address"
         KEY_STORE_HOST=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $1}')
         KEY_STORE_PORT=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}' | gawk -F, '{print $2}')
         KEY_STORE_DATABASE_NAME=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | gawk -F= '{print $2}')
         ;;
         "ORACLE" | "MYSQL")
         hostStringDSN="HostName"
         KEY_STORE_HOST=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${hostStringDSN} | gawk -F= '{print $2}')
         KEY_STORE_PORT=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${portStringDSN} | gawk -F= '{print $2}')
         if [[ "$KEY_STORE_ODBC_TYPE" == "MYSQL" ]]; then
             KEY_STORE_DATABASE_NAME=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbName} | head -1 | gawk -F= '{print $2}')
         else
             KEY_STORE_DATABASE_SERVICE_NAME=$(sed -n "/\[$KEY_STORE_DSN\]/,/\[/p" $PS_HOME/db/system_odbc.ini | grep -i ${dbServiceName} | gawk -F= '{print $2}')
         fi
         ;;
     esac

     echo "[*][$(date +"%T")] - Running smconfigtool for Key Store connection check with DSN: $KEY_STORE_DSN"
     TOOLOPERATION="SMDBCONFIG"
     CREATEONLY_DSN="NO"
     CONNECTION_CHECK="YES"
     check="false"
     if [[ "$KEY_STORE_SSL_ENABLED" = "YES" ]]; then
          $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
          "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK" \
          "1" "$PS_HOME/config/odbcssl/$KEY_STORE_SSL_TRUSTSTORE" \
          "$KEY_STORE_SSL_HOSTNAMEINCERTIFICATE" "$KEY_STORE_SSL_TRUSTPWD"
     else
          $PS_HOME/bin/smconfigtool.sh  $TOOLOPERATION "KEY_STORE" $KEY_STORE_ODBC_TYPE $CREATEONLY_DSN $KEY_STORE_PORT "$KEY_STORE_DSN" "$KEY_STORE_USER" "$KEY_STORE_USER_PASSWORD" "$KEY_STORE_HOST" \
          "$KEY_STORE_DATABASE_NAME" "$KEY_STORE_DATABASE_SERVICE_NAME" "$CONNECTION_CHECK"
     fi

     #incase of failure report and stop executing further as this fatal.
     if [ $? -ne 0 ]; then
       echo "[*][$(date +"%T")] - Error ODBC configuration failed for key store with DSN $KEY_STORE_DSN"
       sleep 1
     else
       check="true"
       echo "[*][$(date +"%T")] - ODBC Key Store connection is successful with DSN $KEY_STORE_DSN"
       break
     fi
   done

   #incase of failure report and stop executing further as this fatal.
   if [[ $check == false ]] ; then
        entroy_check
        echo "[*][$(date +"%T")] - Fatal error: ODBC configuration failed for external key store, exiting in 60 sec"
        update_error_string "Fatal error: ODBC configuration failed for external key store, exiting in 60 sec"
        sleep 60
        exit 1
   fi

 fi
        
    #Only Admin Server perform this
    if [[ "$ROLE" == "admin"  &&  "$isInitializer" == "true" ]]; then
        #This handles for all Store type.
        configure_key_scheme
    fi

    #Update keyStoreEncryptionKey in registry
    if [[ "$KEY_STORE_ENCRYPTION_KEY" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool to update KeyStoreEncryptionKey registry "
        TOOLOPERATION="SMREGCONFIG"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMKEYSTORE_ENCRYPTION_KEY$KEY_STORE_ENCRYPTION_KEY
    fi
else
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Default key store is enabled, Key Store remain same as Policy Store"
fi
#Configure External Key Store Completed.
echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - External Key Store process done"

# Check for key store Failover support
if [[ "$KEY_STORE_TYPE" = "LDAP" ]]; then
    if [[ "$KEY_STORE_ADDITIONAL_HOSTS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key store failover is enabled. Configuring keystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapKeyStore"
        SMREGISTRY_SUBKEY="Server"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${kstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE $i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished keystore failover configuration"
    fi
else
    if [[ "$KEY_STORE_ADDITIONAL_DSNS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - key store failover is enabled. Configuring keystore failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Key"
        SMREGISTRY_SUBKEY="Data Source"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${kstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE,$i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "$SMREGISTRY_SUBKEY" "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished keystore failover configuration"
    fi
fi

# Check for Audit store Failover support
if [[ "$AUDIT_STORE_ADDITIONAL_DSNS" != "" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Audit store failover is enabled. Configuring Audit store failover settings"
    TOOLOPERATION="MODIFYSMREG"
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\Log"
    SMREGISTRY_SUBKEY="Data Source"
    SMREGISTRY_SUBKEY_VALUE=""
    for i in "${audstore[@]}"
    do
      if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
         SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE,$i"
      else
         SMREGISTRY_SUBKEY_VALUE="$i"
      fi
    done
    SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "$SMREGISTRY_SUBKEY" "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished Audit store failover configuration"
fi

# Check for session store Failover support
if [[ "$SESSION_STORE_TYPE" = "LDAP" ]]; then
    if [[ "$SESSION_STORE_ADDITIONAL_HOSTS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Session store failover is enabled. Configuring session store failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\LdapSessionServer"
        SMREGISTRY_SUBKEY="Server"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${sstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE $i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished session store failover configuration"
    fi
else
    if [[ "$SESSION_STORE_ADDITIONAL_DSNS" != "" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Session store failover is enabled. Configuring session store failover settings"
        TOOLOPERATION="MODIFYSMREG"
        SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion\Database\SessionServer"
        SMREGISTRY_SUBKEY="Data Source"
        SMREGISTRY_SUBKEY_VALUE=""
        for i in "${sstore[@]}"
        do
          if [[ "$SMREGISTRY_SUBKEY_VALUE" != "" ]]; then
            SMREGISTRY_SUBKEY_VALUE="$SMREGISTRY_SUBKEY_VALUE,$i"
          else
            SMREGISTRY_SUBKEY_VALUE="$i"
          fi
        done
        SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY "$SMREGISTRY_SUBKEY" "$SMREGISTRY_SUBKEY_VALUE" $SMREGISTRY_SUBKEY_VALUE_TYPE
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Finished session store failover configuration"
    fi
fi


# Import custom agent key in key store if applicable
if [[ "$ROLE" == "admin"  &&  "$isInitializer" == "true" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Importing agent keys"
    if [ -f $CUSTOMER_KEY_FILES/*.* ] ; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Importing agent keys found under $CUSTOMER_KEY_FILES"
        # Use SmKeyImport to import all the key files in $CUSTOMER_KEY_FILES folder.
        for filename in $CUSTOMER_KEY_FILES/*.*; do
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Processing $filename"...
        #sed -i 's|$DEPLOYMENT_FULLNAME|'"$DEPLOYMENT_FULLNAME"'|g' "$filename"
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Using SmKeyImport to import $filename"...
        $PS_HOME/bin/smkeyimport -dsiteminder -w$SUPERUSER_PASSWORD -i"$filename"
        done
    else
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - No custom configuration files found to be imported [$CUSTOMER_KEY_FILES]"
    fi
fi

if [[ "$ROLE" == "ps-maintenance" ]]; then
   
   # Handle to hide the sensistive parmaters
   NON_PROCESSED_ARGS="$MAINTENANACE_OPERATION_ARGS"
   arg_list=""
   pass_param="false"
   for i in $(echo $NON_PROCESSED_ARGS | tr " " "\n")
   do

      if [ "$pass_param" = "true" ]; then
          i="xxxx"
      fi

      pass_param="false"
      if [[ "$MAINTENANACE_OPERATION_NAME" == "smkeyimport"  || "$MAINTENANACE_OPERATION_NAME" == "smkeyexport"  ]]; then
         if [[ "$i" == *"-w"* ]]; then
           arg_list+=" "
           arg_list+="-wxxxx"
         else
           arg_list+=" "
           arg_list+=$i
         fi
      else
          arg_list+=" "
          arg_list+=$i
      fi


      if [ "$i" = "-pass" ]; then
         pass_param="true"
      elif [ "$i" = "-password" ]; then
         pass_param="true"
      elif [ "$i" = "-su" ]; then
         pass_param="true"
      else
         pass_param="false"
      fi

   done
 
   echo "[*][$(date +"%T")] - Initiated maintenance Operation of $MAINTENANACE_OPERATION_NAME with args $arg_list"
   mkdir -p /opt/CA/siteminder/siteminder-data
   cd /opt/CA/siteminder/siteminder-data
  
   # Ignore all the extended log files.. Export to cloud storage only the operation specific logs and files 
   rm -rf /opt/CA/siteminder/log/*.*

   if [[ "$MAINTENANACE_OPERATION_NAME" == "XPSImport" ]]; then

       cp /opt/CA/siteminder/$MAINTENANCE_INPUT_FILE_NAME "$MAINTENANCE_INPUT_FILE_NAME"
       if [[ "$MAINTENANACE_OPERATION_ARGS" == *"-changeset"* ]]; then
         echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
       else
         echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANCE_INPUT_FILE_NAME" "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
       fi
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "smreg" ]]; then
      echo $PS_HOME/tmp/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "smkeytool" ]]; then
       if [[ "$MAINTENANACE_OPERATION_ARGS" == *"-infile"* ]]; then
         cp /opt/CA/siteminder/$MAINTENANCE_INPUT_FILE_NAME "$MAINTENANCE_INPUT_FILE_NAME"
         echo $PS_HOME/bin/smkeytool.sh "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
       elif [[ "$MAINTENANACE_OPERATION_ARGS" == "-keycertfile" ]]; then
         cp /opt/CA/siteminder/$MAINTENANCE_INPUT_FILE_NAME "$MAINTENANCE_INPUT_FILE_NAME"
         echo $PS_HOME/bin/smkeytool.sh "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
       else
         echo $PS_HOME/bin/smkeytool.sh "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
       fi
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "smkeyexport" ]]; then
      echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "smkeyimport" || "$MAINTENANACE_OPERATION_NAME" == "XPSExplorer" ]]; then
      cp /opt/CA/siteminder/$MAINTENANCE_INPUT_FILE_NAME "$MAINTENANCE_INPUT_FILE_NAME"
      echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "smldapsetup" ]]; then
     MAINTENANACE_OPERATION_ARGS="status -v > ldapstatus"

     echo "[*][$(date +"%T")] - Initiated maintenance Operation of $MAINTENANACE_OPERATION_NAME with modified args $MAINTENANACE_OPERATION_ARGS"
     # Ignore all other arguments of smldapsetup, only support status option
     echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
   elif [[ "$MAINTENANACE_OPERATION_NAME" == "XPSSecurity" ]]; then
      cp /opt/CA/siteminder/$MAINTENANCE_INPUT_FILE_NAME "$MAINTENANCE_INPUT_FILE_NAME"
      echo $PS_HOME/tmp/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh																 
   else
       echo $PS_HOME/bin/$MAINTENANACE_OPERATION_NAME "$MAINTENANACE_OPERATION_ARGS" > runCommand.sh
   fi
   chmod +x runCommand.sh
   ./runCommand.sh
   if [ $? -ne 0 ]; then
     echo "Error occured while initiating the import operation"
   else
     # Empty smaccess is generated. check whether smaccess has got some data. Delete the empty smaccess.log 
     [ -s /opt/CA/siteminder/log/smaccess.log ] || rm -rf /opt/CA/siteminder/log/smaccess.log																											
     echo "Successfully ran the maintenance operation $MAINTENANACE_OPERATION_NAME"
     archive_and_send_data
   fi

fi


#Since this mandatory operation to support readiness and liveness probe
# Set store initialization flag, after that.
# "isInitializer" will be true for ADMIN POD ordinal '0' only
if [ "$isInitializer" == "true" ]; then
   add_default_mandatory_objects
   
   # check for policy store init object
   # if not present create init object
   #check_for_policy_store_init_object

   # Update AgentConnectionMaxLifetime parameter in XPS Store
   if [ ! -z "$AGENT_CONN_MAX_LIFETIME" ]; then
       updateAgentConnMaxLifetime
   fi
fi

#Enable Radius Server Ports
if [ "$ROLE" != "admin" ]; then
    if [[ "$CA_SM_PS_ENABLE_RADIUS_SERVER" = "YES" ]]; then
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Enabling Policy server as Radius Server"
        TOOLOPERATION="SMREGCONFIG"
        $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMRADIUS_ENABLED
        echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - policy server enabled to listen on radius UDP ports"
    fi
fi

# Enabling smtrace for policy server
if [[ "$CA_SM_PS_TRACE_ENABLE" = "YES" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for smtrace enabling"
    TOOLOPERATION="SMREGCONFIG"
    SMTRACECONF="$SMTRACECONF"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMTRACECONF
fi

# Enabling sminmemorytrace for policy server
if [[ "$CA_SM_PS_INMEMORY_TRACE_ENABLE" = "YES" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for sminmemorytrace enabling"

    TOOLOPERATION="SMREGCONFIG"
    SMINMEMORYENABLE="$SMINMEMORYENABLE$CA_SM_PS_INMEMORY_TRACE_ENABLE"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMINMEMORYENABLE

    SMINMEMORYCONF="$SMINMEMORYCONF"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMINMEMORYCONF

    SMINMEMORYSIZE="$SMINMEMORYSIZE$CA_SM_PS_INMEMORY_TRACE_FILE_SIZE"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMINMEMORYSIZE

    SMINMEMORY_FILEPATH="$SMINMEMORY_FILEPATH$CA_SM_PS_INMEMORY_TRACE_OUTPUT"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMINMEMORY_FILEPATH
fi


# OVM app will be running in Administrative POD. All the policy servers sends the metrics and stats to OVM running in Administrative POD

if [[ "$CA_SM_PS_ENABLE_OVM" = "YES" ]]; then
  echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Updating OVM configurations"
  if [ "$ROLE" == "admin" ] && [ $ordinal -eq 0 ]; then
     sed -i '$ a nete.conapi.service.monagn.allowRemote=true' $PS_HOME/config/conapi.conf

  else
     OVM_REMOTE_SERVICE="$(echo "$OVM_SERVICE_TOCONNECT" | cut -d',' -f1)"
     echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - OVM service to connect $OVM_REMOTE_SERVICE"
     OVM_REMOTE_PORT="$(echo "$OVM_SERVICE_TOCONNECT" | cut -d',' -f2)"
     echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - OVM port to connect $OVM_REMOTE_PORT"

     sed -i '/nete.conapi.service.monagn.port/d' $PS_HOME/config/conapi.conf
     sed -i '/nete.conapi.service.monagn.host/d' $PS_HOME/config/conapi.conf
     sed -i '$ a nete.conapi.service.monagn.host='$OVM_REMOTE_SERVICE'' $PS_HOME/config/conapi.conf
     sed -i '$ a nete.conapi.service.monagn.port='$OVM_REMOTE_PORT'' $PS_HOME/config/conapi.conf
     sed -i '$ a nete.conapi.service.monagn.allowRemote=false' $PS_HOME/config/conapi.conf
  fi
fi
# Enabling IDM SSO Integration by adding registry (used for SSO-IDM integration)
if [[ "$CA_SM_PS_ENABLE_CA_IDENITITY_MANAGER_INTEGRATION" = "YES" ]]; then
    echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - Running smconfigtool for enabling Integration of CA Single Sign-On with CA Identity Manager"
    TOOLOPERATION="MODIFYSMREG"
    SMREGISTRY_KEY="HKEY_LOCAL_MACHINE\SOFTWARE\Netegrity\SiteMinder\CurrentVersion"
    SMREGISTRY_SUBKEY="ImsInstalled"
    SMREGISTRY_SUBKEY_VALUE="8.0"
    SMREGISTRY_SUBKEY_VALUE_TYPE="REG_SZ"
    $PS_HOME/bin/smconfigtool.sh $TOOLOPERATION $SMREGISTRY_KEY $SMREGISTRY_SUBKEY $SMREGISTRY_SUBKEY_VALUE $SMREGISTRY_SUBKEY_VALUE_TYPE
fi

enableTags


echo "[*][$(date +"%T")][POLICY_SERVER_CONTAINER] - $FILE_NAME: **complete**"

