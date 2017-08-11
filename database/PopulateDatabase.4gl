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

IMPORT security

FUNCTION db_populate_tables()
    DEFINE hashed_pass VARCHAR(255)
    
    WHENEVER ERROR STOP

    # Add user foo
    LET hashed_pass = Security.BCrypt.HashPassword("foo",NULL)  
    INSERT INTO users VALUES("foo",hashed_pass)

    # Add user demo
    LET hashed_pass = Security.BCrypt.HashPassword("demo",NULL)  
    INSERT INTO users VALUES("demo",hashed_pass)
    
END FUNCTION