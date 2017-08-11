#
# FOURJS_START_COPYRIGHT(U,2012)
# Property of Four Js*
# (c) Copyright Four Js 2012, 2017. All Rights Reserved.
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
# security requirements. We advise especially to improve the encryption system. 

#+
#+ Database constant name
#+
PRIVATE CONSTANT C_DATABASE = "simplesso"

#+
#+ Connect to database
#+
PUBLIC FUNCTION DBConnect()
  TRY
    CONNECT TO C_DATABASE
  CATCH
    RETURN FALSE
  END TRY

  # Make sure to have committed read isolation level and wait for locks
  WHENEVER ERROR CONTINUE   # Ignore SQL errors if instruction not supported
  SET ISOLATION TO COMMITTED READ
  SET LOCK MODE TO WAIT 
  WHENEVER ERROR STOP
  RETURN TRUE

END FUNCTION

#+
#+ Disconnect from database
#+
PUBLIC FUNCTION DBDisconnect()
  DISCONNECT C_DATABASE  
END FUNCTION

#+
#+ Clean all expired sessions
#+
PUBLIC FUNCTION cleanSessions()
    DEFINE dt DATETIME YEAR TO SECOND

    LET dt = CURRENT
    TRY
        DELETE FROM sessions WHERE expiredate <= dt
    CATCH
        DISPLAY status, " ", SQLCA.sqlerrm
    END TRY
END FUNCTION

#+
#+ Clean all expired relay state
#+
PUBLIC FUNCTION cleanRelayState()
    DEFINE dt DATETIME YEAR TO SECOND

    LET dt = CURRENT
    TRY
        DELETE FROM relaystate WHERE expiredate <= dt
    CATCH
        DISPLAY status, " ", SQLCA.sqlerrm
    END TRY
END FUNCTION
