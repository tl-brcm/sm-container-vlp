#!/bin/sh
################################################################################
#                     "smconfigtool" Installation Script
#                Copyright 2006 CA. All rights reserved.
################################################################################

. "/opt/CA/siteminder/ca_ps_env.sh"

java="$NETE_JRE_ROOT/bin/java"

#use only for debug
#echo "LD_LIBRARY_PATH = $LD_LIBRARY_PATH"
TOOLOPERATION=$1;
cp="$NETE_PS_ROOT/bin/smconsole.jar:$NETE_PS_ROOT/bin/jars/smconfigtool.jar:$NETE_PS_ROOT/bin/jars/sqljdbc4.jar:$NETE_PS_ROOT/bin/jars/smjavasdk2.jar:$NETE_PS_ROOT/bin/jars/smagentapi.jar:$NETE_PS_ROOT/bin/jars/smcrypto.jar:$NETE_PS_ROOT/bin/thirdparty/bc-fips-1.0.2.3.jar:$NETE_PS_ROOT/bin/jars/oraclepki.jar:$NETE_PS_ROOT/bin/jars/osdt_core.jar:$NETE_PS_ROOT/bin/jars/osdt_cert.jar:$NETE_PS_ROOT/bin/jars/ojpse.jar:$NETE_PS_ROOT/bin/jars/mariadb-java-client-2.7.5.jar"
#SMCONFIGDB operations
if [ "$TOOLOPERATION" == "SMDBCONFIG" ]; then
    STORE_TYPE=$2;
    STORE_ODBC_TYPE=$3;
    CREATEONLYDSN=$4;
    SERVER_PORT=$5;
    STORE_DSN=$6;
    STORE_USER=$7;
    STORE_USER_PASSWORD=$8;
    SERVER_NAME=$9;
    DATABASE_NAME=${10};
    SERVICE_NAME=${11};
    CONNECTION_CHECK=${12};
    if [ "$#" -gt "13" ]; then
    #echo "****SSL Enabled arguments passed.****"
    STORE_SSL_ENABLED=${13}
    STORE_SSL_TRUSTSTORE=${14}
    STORE_SSL_HOSTNAMEINCERTIFICATE=${15}
    STORE_SSL_TRUSTPWD=${16}

    fi

    # converting odbc type to lowercase string
    typeset -l STORE_ODBC_TYPE

    #echo "[*][$(date +"%T")] - store type:$STORE_TYPE|dsnOnly:$CREATEONLYDSN|port:$SERVER_PORT|DSN:$STORE_DSN|username:$STORE_USER|userpwd:*****|server:$SERVER_NAME|databaseName:$DATABASE_NAME|role:$ROLE"

    if [[ "$STORE_ODBC_TYPE" == "mssql" ]]; then
        if [ "$#" -gt "13" ]; then
           $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MSSQL null true $ROLE $CONNECTION_CHECK $STORE_SSL_ENABLED "$STORE_SSL_TRUSTSTORE" "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
        else
           $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MSSQL null true $ROLE $CONNECTION_CHECK
        fi
    elif [[ "$STORE_ODBC_TYPE" == "oracle" ]]; then
       cp="$NETE_PS_ROOT/bin/smconsole.jar:$NETE_PS_ROOT/bin/jars/smconfigtool.jar:$NETE_PS_ROOT/bin/jars/ojdbc8.jar:$NETE_PS_ROOT/bin/jars/oraclepki.jar:$NETE_PS_ROOT/bin/jars/osdt_core.jar:$NETE_PS_ROOT/bin/jars/osdt_cert.jar:$NETE_PS_ROOT/bin/jars/ojpse.jar"
       if [ "$#" -gt "13" ]; then
           $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_ORACLE "$SERVICE_NAME" true $ROLE $CONNECTION_CHECK $STORE_SSL_ENABLED $STORE_SSL_TRUSTSTORE "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
       else
           $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_ORACLE "$SERVICE_NAME" true $ROLE $CONNECTION_CHECK
       fi
    elif [[ "$STORE_ODBC_TYPE" == "mysql" ]]; then
        if [[ "$CREATEONLYDSN"  == "NO" && "$CONNECTION_CHECK" == "NO" ]]; then
            # adding database name in sql files
            if [ "$STORE_TYPE" == "POLICY_STORE" ]; then
                cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ps.sql.unicode $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ks.sql.unicode
                sed -i "s/databaseName/$DATABASE_NAME/g" $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ps.sql.unicode
                sed -i "s/databaseName/$DATABASE_NAME/g" $NETE_PS_ROOT/xps/db/Tier2DirSupport/MySQL/MySQL.sql.unicode
            elif [ "$STORE_TYPE" == "KEY_STORE" ]; then
                if [ ! -f "$NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ks.sql.unicode" ]; then
                    cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ps.sql.unicode $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ks.sql.unicode
                fi
                # use sm_mysql_ks.sql file for schema creation
                sed -i "s/databaseName/$DATABASE_NAME/g" $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ks.sql.unicode
            elif [ "$STORE_TYPE" == "SESSION_STORE" ]; then

                if [ ! -f $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss_org.sql ]; then
                  cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss.sql $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss_org.sql
                  echo "sm_mysql_ss.sql file is copied as orginal file"
                else
                  cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss_org.sql $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss.sql
                  echo "sm_mysql_ss_org.sql file is copied as runtime file"
                fi

                sed -i "s/databaseName/$DATABASE_NAME/g" $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_ss.sql

            elif [ "$STORE_TYPE" == "AUDIT_STORE" ]; then

                if [ ! -f $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs_org.sql ]; then
                  cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs.sql $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs_org.sql
                  echo "sm_mysql_logs.sql file is copied as orginal file"
                else
                  cp $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs_org.sql $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs.sql
                  echo "sm_mysql_logs_org.sql file is copied as runtime file"
                fi

                sed -i "s/databaseName/$DATABASE_NAME/g" $NETE_PS_ROOT/db/tier2/MySQL/sm_mysql_logs.sql
            fi
        fi

        if [ "$#" -gt "13" ]; then
            $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MYSQL null true $ROLE $CONNECTION_CHECK $STORE_SSL_ENABLED "$STORE_SSL_TRUSTSTORE" "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
        else
           $java  -classpath $cp com.ca.sm.smconfigtool.ConfigSmOdbcStore $STORE_TYPE $CREATEONLYDSN $SERVER_PORT "$STORE_DSN" "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MYSQL null true $ROLE $CONNECTION_CHECK
        fi
    fi

    if [ $? -ne 0 ]; thenf
        echo "[*][$(date +"%T")] - ConfigSmOdbcStore failed"
        exit 2
    fi
elif [ "$TOOLOPERATION" == "SESSION_LDAP" ]; then

    $java  -classpath $cp com.ca.sm.smconfigtool.SmRegistryUpdate $1 $2 $3 $4 $5 $6 $7
    if [ $? -ne 0 ]; then
        echo "[*][$(date +"%T")] - SmRegistryUpdate failed"
        exit 2
    fi

elif [ "$TOOLOPERATION" == "EXECUTE_SQL_QUERY" ]; then
    STORE_TYPE=$2;
    QUERY_NAME=$3;
    STORE_ODBC_TYPE=$4;
    SERVER_PORT=$5;
    STORE_USER=$6;
    STORE_USER_PASSWORD=$7;
    SERVER_NAME=$8;
    DATABASE_NAME=$9;
    SERVICE_NAME=${10};
    if [ "$#" -gt "11" ]; then
    STORE_SSL_ENABLED=${11};
    STORE_SSL_TRUSTSTORE=${12};
    STORE_SSL_HOSTNAMEINCERTIFICATE=${13};
    STORE_SSL_TRUSTPWD=${14};
    fi

    # converting odbc type to lowercase string
    typeset -l STORE_ODBC_TYPE

    if [[ "$STORE_ODBC_TYPE" == "mssql" ]]; then
        if [ "$#" -gt "11" ]; then
        $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MSSQL null $ROLE $STORE_SSL_ENABLED "$STORE_SSL_TRUSTSTORE" "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
        else
        $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MSSQL null $ROLE
        fi
    elif [[ "$STORE_ODBC_TYPE" == "oracle" ]]; then
       cp="$NETE_PS_ROOT/bin/smconsole.jar:$NETE_PS_ROOT/bin/jars/smconfigtool.jar:$NETE_PS_ROOT/bin/jars/ojdbc8.jar:$NETE_PS_ROOT/bin/jars/oraclepki.jar:$NETE_PS_ROOT/bin/jars/osdt_core.jar:$NETE_PS_ROOT/bin/jars/osdt_cert.jar:$NETE_PS_ROOT/bin/jars/ojpse.jar"
       if [ "$#" -gt "13" ]; then
           $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_ORACLE "$SERVICE_NAME" $ROLE $STORE_SSL_ENABLED $STORE_SSL_TRUSTSTORE "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
        else
           $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_ORACLE "$SERVICE_NAME" $ROLE
        fi
    elif [[ "$STORE_ODBC_TYPE" == "mysql" ]]; then
        if [ "$#" -gt "11" ]; then
        $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MYSQL null $ROLE $STORE_SSL_ENABLED "$STORE_SSL_TRUSTSTORE" "$STORE_SSL_TRUSTPWD" "$STORE_SSL_HOSTNAMEINCERTIFICATE"
        else
        $java  -classpath $cp com.ca.sm.smconfigtool.ExecuteSQLScript $STORE_TYPE $QUERY_NAME $SERVER_PORT "$STORE_USER" "$STORE_USER_PASSWORD" "$SERVER_NAME" "$DATABASE_NAME" DB_MYSQL null $ROLE
        fi
    fi

elif [ "$TOOLOPERATION" == "SMREGCONFIG" ]; then
        #SMREGCONFIG operations
        #capturing all args so that we can supply to smonfigtool
        i=1
        inputargs=""
        for arg do
            if [ "$i" != "1" ]; then
                inputargs="$inputargs $arg"
            fi
            i=$((i + 1))
        done
        #use only for debug
        #echo "input args to smconfigtool: $inputargs"

        $java  -classpath $cp com.ca.sm.smconfigtool.SmRegistryUpdate $inputargs
        if [ $? -ne 0 ]; then
           echo "[*][$(date +"%T")] - SmRegistryUpdate failed"
           exit 2
        fi

elif [ "$TOOLOPERATION" == "FETCH_ALL_STORE_INFO" ]; then
        BOOTSTRAP_INFO_TYPE=$2;
        echo "[*][$(date +"%T")] - calling bootstrap fetch for $ADMIN_SERVICE_NAME:$SUPERUSER_NAME:$BOOTSTRAP_INFO_TYPE"
        #used only for debuggin LD_LIBRARY_PATH
        #echo "[*][$(date +"%T")] - Environment Path = $LD_LIBRARY_PATH"
        $java  -classpath $cp com.ca.sm.smconfigtool.FetchBSInfoFromAdminServer $BOOTSTRAP_INFO_TYPE "$ADMIN_SERVICE_NAME" "$SUPERUSER_NAME" "$SUPERUSER_PASSWORD" 
               
        if [ $? -ne 0 ]; then
           exit 2
        fi
elif [ "$TOOLOPERATION" == "MODIFYSMREG" ]; then
        #use only for debug
        #echo "Path=$2 Key=$3 Value=$4 "
        $java  -classpath $cp com.ca.sm.smconfigtool.ModifySmRegistry "$2" "$3" "$4" "$5"
fi
