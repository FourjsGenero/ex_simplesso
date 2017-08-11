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
# security requirements.
#

IMPORT com
IMPORT XML
IMPORT FGL WSHelper
IMPORT FGL HTTPHelper
IMPORT security

#+
#+ Create session in database and sets a server cookie with UUID as value
#+  for given application path 
#+
#+ @param username login name
#+
#+ @param expireDate expiration date of cookie
#+
#+ @param path application path
#+
#+ @return cookie array to set in server response to grant access to this user 
#+
FUNCTION createSession (username, expireDate, path)
  DEFINE username     VARCHAR(255)
  DEFINE sessionID    VARCHAR(255)
  DEFINE path         STRING
  DEFINE expireDate  DATETIME YEAR TO SECOND
  DEFINE cookies WSHelper.WSServerCookiesType
  
  LET sessionid = security.RandomGenerator.CreateUUIDString()
  # store the sessionid in the database
  TRY
    INSERT INTO sessions VALUES (username, sessionid, expireDate)
  CATCH
    DISPLAY status, " ", SQLCA.SQLERRD[2]
  END TRY
  LET cookies[1].NAME    = HTTPHelper.C_COOKIE_NAME
  LET cookies[1].VALUE   = sessionid  
  # Change following line if you want the cookie to be set for entire gas
  LET cookies[1].path    = getCookiePath (path) # Cookie set for /ua/r/app 
  LET cookies[1].expires = expireDate
  RETURN cookies
  
END FUNCTION

#+
#+ Extract the application path from an absolute URL
#+  to be set as cookie path
#+
#+ @param url Absolute application URL (ex: http://host:port/gas/ua/r/myapp)
#+
#+ @return URL path (ex : /gas/ua/r/myapp) 
#+
PRIVATE
FUNCTION getCookiePath(url)
  DEFINE  url    STRING
  DEFINE  ind     INTEGER
  DEFINE  ind2    INTEGER 
  LET ind = url.getIndexOf("://",1)
  LET ind2 = url.getIndexOf("/",ind+3)
  IF ind2<1 THEN
    RETURN NULL # no host and port
  ELSE
    RETURN url.subString(ind2,url.getLength())
  END IF 
END FUNCTION


#+
#+ Check user authentication
#+
#+ @param user login name
#+
#+ @param pwd user password
#+
#+ @return TRUE is user is authenticated in users database, FALSE otherwise
#+
FUNCTION checkAuth (user, pwd)

  DEFINE user, pwd STRING
  DEFINE auth BOOLEAN
  DEFINE hash VARCHAR(255)

    # get the hashed password from the database
    SELECT password INTO hash FROM users WHERE login=USER
    IF status==NOTFOUND THEN
        LET auth = FALSE
    ELSE
        # check the given password against the hash
        IF security.BCrypt.CheckPassword(pwd,hash) THEN
            LET auth = TRUE
        ELSE
            LET auth = FALSE
        END IF
    END IF
  RETURN auth
    
END FUNCTION

#+
#+ Check session from opaque cookie value ID
#+  and return user is valid, NULL otherwise
#+
#+ @param sid the cookie UUIR value
#+
#+ @return username registered in sessions database for given sid or NULL
#+
FUNCTION checkSession (sid) 

  DEFINE sid STRING
  DEFINE auth BOOLEAN
  DEFINE p_login VARCHAR(255)
  DEFINE now  DATETIME YEAR TO SECOND

  LET now = CURRENT
  
  WHENEVER ERROR CONTINUE
  SELECT login 
    INTO p_login 
    FROM sessions 
    WHERE opaqueid = sid AND expiredate>now
    
  CASE SQLCA.sqlcode
   WHEN NOTFOUND
     LET auth = FALSE

   WHEN 0
     LET auth = TRUE

   OTHERWISE
     LET auth = FALSE
     DISPLAY "ERROR : checksession"
   
  END CASE
  WHENEVER ERROR STOP
  
  RETURN auth, p_login
    
END FUNCTION

#+
#+ Remove given ID from sessions table
#+
#+ @param sid opaque UUID from session table
#+
FUNCTION removeSession (sid)
  DEFINE sid  VARCHAR(255)
  
  WHENEVER ERROR CONTINUE
  DELETE FROM sessions WHERE opaqueid == sid
  WHENEVER ERROR STOP
  
END FUNCTION

#+
#+ Create relay state to follow re-login steps
#+  not validated as long as valid == 0
#+
#+ @param username login of user that needs relogin
#+
#+ @param sessionID GAS ua session ID
#+
#+ @expireDate expiration date of relay state in database
#+
#+ @return UUID representing the relay state key 
#+
FUNCTION createRelayState (username,sessionID, expireDate)
  DEFINE uuid         VARCHAR(255)
  DEFINE username     VARCHAR(255)
  DEFINE sessionID    VARCHAR(255)
  DEFINE expireDate  DATETIME YEAR TO SECOND

  LET uuid = security.RandomGenerator.CreateUUIDString()
  # store the sessionid in the database
  TRY
    INSERT INTO relaystate VALUES (uuid, username, sessionid, 0, expireDate)
    RETURN uuid
  CATCH
    DISPLAY status, " ", SQLCA.SQLERRD[2]
    RETURN NULL
  END TRY
  
END FUNCTION

#+
#+ Validates relaystate if user is found
#+  and return ua session or null in case of error
#+
#+ @param p_uuid UUID of relay state to be validated
#+
#+ @param p_user username to be check for that relay state
#+
#+ @return GAS ua session ID to be used for /ua/resume request, or NULL if invalid
#+
FUNCTION validateRelayState (p_uuid, p_user)
  DEFINE  p_uuid    VARCHAR(255)
  DEFINE  p_user    VARCHAR(255)
  DEFINE  p_session VARCHAR(255)
  DEFINE  now       DATETIME YEAR TO SECOND

  LET p_session = NULL
  LET now = CURRENT 
  TRY
    UPDATE relaystate set valid = 1 WHERE uuid == p_uuid AND login == p_user AND expiredate > now
    SELECT sessionid
      INTO p_session
      FROM relaystate
      WHERE uuid == p_uuid AND login == p_user AND expiredate > now 
  CATCH
    DISPLAY "ERROR (validateRelayState) :",STATUS
  END TRY
  RETURN p_session
END FUNCTION

#+
#+ Returns whether given relay state has been validated with validateRelayState
#+  valid entry == 1
#+
#+ @param p_uuid UUID of relay state
#+
#+ @return 1 If current relay state has been validated, 0 otherwise
#+
FUNCTION checkRelayState(p_uuid)
  DEFINE  p_uuid    VARCHAR(255)
  DEFINE  p_valid   INTEGER
  DEFINE  now       DATETIME YEAR TO SECOND

  LET p_valid = 0
  LET now = CURRENT
  TRY
  SELECT valid
    INTO p_valid
    FROM relaystate
    WHERE uuid == p_uuid AND expiredate > now
  CATCH
    DISPLAY "ERROR (checkRelayState) :",STATUS
  END TRY
  RETURN p_valid
  
END FUNCTION

#+
#+ Remove given relay state once re-login is complete
#+
#+ @param p_uuid UUID of relay state
#+
FUNCTION removeRelayState(p_uuid)
  DEFINE  p_uuid    VARCHAR(255)
  WHENEVER ERROR CONTINUE
  DELETE FROM relaystate WHERE uuid == p_uuid
  WHENEVER ERROR STOP
END FUNCTION
  
  
