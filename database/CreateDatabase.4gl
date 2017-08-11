#
# FOURJS_START_COPYRIGHT(U,2017)
# Property of Four Js*
# (c) Copyright Four Js 2017, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these samples
# are accurate and suitable for your purposes. Their inclusion is purely for
# information purposes only.
# FOURJS_END_COPYRIGHT
#

#
# DISCLAIMER: 
# Functions contained in this file are only some examples for internal use    
# On a production site, these functions need to be entirely reviewed for matching 
# security requirements.
#

MAIN
    DATABASE simplesso

    CALL db_drop_tables()
    CALL db_create_tables()
    CALL db_populate_tables()
END MAIN

#+ Create all tables in database.
FUNCTION db_create_tables()
    WHENEVER ERROR STOP

    EXECUTE IMMEDIATE "CREATE TABLE sessions (
        login VARCHAR(255) NOT NULL,
        opaqueid VARCHAR(255) NOT NULL,
        expiredate DATETIME YEAR TO SECOND NOT NULL)"
    EXECUTE IMMEDIATE "CREATE TABLE users (
        login VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL)"
    EXECUTE IMMEDIATE "CREATE TABLE relaystate (
        uuid VARCHAR(255) NOT NULL,
        login VARCHAR(255) NOT NULL,
        sessionid VARCHAR(255) NOT NULL,
        valid INTEGER NOT NULL,
        expiredate DATETIME YEAR TO SECOND NOT NULL)"

END FUNCTION

#+ Drop all tables from database.
FUNCTION db_drop_tables()
    WHENEVER ERROR CONTINUE

    EXECUTE IMMEDIATE "DROP TABLE sessions"
    EXECUTE IMMEDIATE "DROP TABLE users"
    EXECUTE IMMEDIATE "DROP TABLE relaystate"

END FUNCTION


