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


IMPORT COM
IMPORT UTIL
IMPORT Security
IMPORT FGL DBase
IMPORT FGL HTTPHelper
IMPORT FGL WSHelper
IMPORT FGL SSOUserFunctions

#+
#+ Cleanup database every hour
#+
PRIVATE CONSTANT C_CLEANUP_DELAY        =   3600 

#+
#+ Base URL depending on deployment path 
#+ TO BE MODIFIED IF DEPLOYED ELSEWHERE
#+ 
PRIVATE CONSTANT C_BASE_PATH = "/ws/r/SimpleSSOServiceProvider/"

#+
#+ Duration of the authentication when keepconnected checkbox is unchecked 
#+
PRIVATE CONSTANT COOKIE_VALIDITY = INTERVAL(10) SECOND TO SECOND

#+
#+ Duration of the authentication when keepconnected checkbox is checked
#+
PRIVATE CONSTANT COOKIE_KEEP     = INTERVAL(1) DAY TO DAY

#+
#+ Duration of re-login validation
#+
PRIVATE CONSTANT RELOGIN_TIME    = INTERVAL(30) SECOND TO SECOND

#+
#+ Server main
#+
MAIN
  DEFINE  req       com.HttpServiceRequest
  DEFINE  ind       INTEGER
  DEFINE  path      STRING
  DEFINE  remoteip  STRING
  DEFINE  baseurl   STRING
  DEFINE  HTTPSON   STRING
  DEFINE  operation STRING
  
  # Initialize DB
  IF NOT DBase.DBConnect() THEN
    DISPLAY "unable to connect"
    EXIT PROGRAM (1)
  END if
    
  # Initialize connection layer
  CALL com.WebServiceEngine.SetOption("readwritetimeout",60)
  CALL com.WebServiceEngine.SetOption("connectiontimeout",25)  
  # Start server
  CALL com.WebServiceEngine.Start()
  
  WHILE TRUE
    TRY
      LET req = com.WebServiceEngine.GetHttpServiceRequest(C_CLEANUP_DELAY)
      IF req IS NULL THEN
        CALL Cleanup()
      ELSE
      
        LET path = req.getUrlPath()
        LET remoteip = req.getRequestHeader(C_X_FOURJS_REMOTE_ADDR)
        DISPLAY "Access ("||remoteip||"):incoming request : "||path
        
        LET ind = path.getIndexOf(C_BASE_PATH,1)
        IF ind<1 THEN
          CALL req.sendTextResponse(400,"Bad request","Invalid request")
          DISPLAY "ERROR ("||remoteip||"):invalid request"
          
        ELSE

          #
          # Retrieve operation after base path
          #
          LET operation = path.subString(ind+C_BASE_PATH.getLength(),path.getLength())

          #
          # Rebuild "real" base URL taking HTTPS into account
          #
          LET HTTPSON = req.getRequestHeader(HTTPHelper.C_X_FOURJS_HTTPS)
          IF HTTPSON IS NOT NULL THEN
            LET baseURL = "https://"
          ELSE
            LET baseURL = "http://"
          END IF

          # Host name
          LET baseURL = baseURL||req.getUrlHost()

          # Port (if any)
          IF req.getUrlPort() != 0 THEN
            LET baseURL = baseURL||":"||req.getUrlPort()
          END IF

          # Path
          LET path = path.subString(1,ind-1)
          IF path IS NOT NULL THEN
            LET baseURL = baseURL||path
          END IF

          # Dispatch according to operation
          CALL DispatchService(req, baseURL, operation)
        END IF
        
        DISPLAY "ACCESS ("||remoteip||"):response returned"
      END IF
      
    CATCH
      DISPLAY "ERROR : ",STATUS
      EXIT WHILE 
    END TRY
    
  END WHILE 

  # Handle expirations
  CALL Cleanup()

  # Close database
  CALL DBase.DBDisconnect()

  DISPLAY "MSG : Server stopped"

END MAIN

#+
#+ Removes all session and relay state entries
#+  if expired
#+
PRIVATE
FUNCTION Cleanup()
  CALL DBase.cleanSessions()
  CALL DBase.cleanRelayState()
END FUNCTION 

#+
#+ Dispatch request according to path after baseURL
#+  in other words, it is a switch about the different operations
#+  /Delegate, /Validate and /Prompt
#+
#+ @param req current HTTPServiceRequest instance
#+ @param baseURL server base URL (https://host:port/gas)
#+ @param operation name (Delegate, Validate or Prompt)
#+
FUNCTION DispatchService(req, baseURL, operation)
  DEFINE  req       com.HttpServiceRequest
  DEFINE  baseURL   STRING
  DEFINE  operation STRING
  DEFINE  ind       INTEGER
  DEFINE  query     WSHelper.WSQueryType
  
  LET ind = operation.getIndexOf("/",1)
  IF ind>0 THEN
    CALL req.sendTextResponse(400,"Bad request","Invalid path")
    DISPLAY "ERROR : invalid path"
    
  ELSE
    # Retrieve decoded URL query string
    CALL req.getURLQuery(query)
    
    # Dispatch according to operation
    CASE operation
    
      WHEN HTTPHelper.C_PROMPT
        CALL DoPrompt(req, baseURL, query)
        
      WHEN HTTPHelper.C_DELEGATE
        CALL DoDelegate(req, baseURL, query)

      WHEN HTTPHelper.C_VALIDATE
        CALL DoValidate(req, baseURL, query)

      OTHERWISE
        CALL req.sendTextResponse(501,NULL,"operation not implemented")
        DISPLAY "ERROR : unknown service '"||operation||"'"
        
    END CASE 
    
  END IF
END FUNCTION

#+
#+ Authenticate user by checking cookie presence
#+  if no cookie at all => send welcome page
#+  if cookie has expired => send expire page
#+  if cookie ok => start ua proxy
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
#+ @param originURL initial URL that triggered the delegate (/ua/r/app)
#+
PRIVATE
FUNCTION DelegateAuthenticate(req, baseURL, query, originURL)
  DEFINE  req             com.HttpServiceRequest
  DEFINE  baseURL         STRING        # Delegate service URL
  DEFINE  query           WSHelper.WSQueryType
  DEFINE  originURL       STRING
  DEFINE  cookieValue     STRING
  DEFINE  ind             INTEGER
  DEFINE  ok              BOOLEAN
  DEFINE  p_user          STRING
  
  # Check for cookie presence
  LET cookieValue = req.findRequestCookie(HTTPHelper.C_COOKIE_NAME)
  IF cookieValue IS NULL THEN
  
    # No cookie send welcome page and url to return back after credentials validation
    CALL HTTPHelper.SendWelcomePage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?back="||util.Strings.urlEncode(originURL))
    
  ELSE
  
    # Check cookie validity
    CALL SSOUserFunctions.checkSession (cookieValue) RETURNING ok, p_user
    
    IF ok THEN # Cookie valid, user authenticated

      # Forward user as environment variable to FGLRUN in charge of that user
      # Put here all other environment variable related to user 
      CALL req.setResponseHeader(C_X_FOURJS_ENVIRONEMENT_||"user", p_user)
      
      # Forward prompt id in case of re-login in order to keep user
      CALL req.setResponseHeader(C_X_FOURJS_FGL_AUTO_LOGOUT_PROMPT_QUERY, p_user)

      # Tell dispatch to allow application start
      CALL req.sendResponse(307,HTTPHelper.C_GENERO_INTERNAL_DELEGATE)
      
      # Check for disconnection in query string (once user has been validated)
      LET ind = query.search("name","disconnect")
      IF ind>0 THEN
        CALL SSOUserFunctions.removeSession( cookieValue) 
      END IF
      
    ELSE
      # Cookie invalid or expired, send expire page and url to return back after credential validation
      CALL sendExpirePage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?back="||util.Strings.urlEncode(originURL))

    END IF   
    
  END IF
  
END FUNCTION

#+
#+ Check whether /ua/resume request has a valid relaystate (valid entry == 1)
#+  in order to ensure that it comes from the ReValidateUser 
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
#+ @param originURL initial URL that triggered the delegate (/ua/r/app)
#+
PRIVATE
FUNCTION DelegateResumeApp(req, baseURL, query, originURL)
  DEFINE  req             com.HttpServiceRequest
  DEFINE  baseURL         STRING        # Delegate service URL
  DEFINE  query           WSHelper.WSQueryType
  DEFINE  originURL       STRING
  DEFINE  ind             INTEGER
  
  # Ensure that relaystate query string param is valid 
  LET ind = query.search("name","relaystate")
  IF ind>0 THEN
    IF SSOUserFunctions.checkRelayState(query[ind].value) == 1 THEN
      # Remove relaystate
      CALL SSOUserFunctions.removeRelayState(query[ind].value)
    
      # relay state has been validated => forward resume request to proxy
      CALL req.sendResponse(307, HTTPHelper.C_GENERO_INTERNAL_DELEGATE)
    ELSE
      # User not valid, retry
      CALL SendErrorPage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?relaystate="||query[ind].VALUE)
    END IF
  ELSE
    # Raise error page
    CALL SendErrorPage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?back="||util.strings.urlEncode(originURL))
  END IF  

END FUNCTION

#+
#+ Process service /Delegate operation
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
FUNCTION DoDelegate(req, baseURL, query)
  DEFINE  req             com.HttpServiceRequest
  DEFINE  baseURL         STRING        # Delegate service URL
  DEFINE  query           WSHelper.WSQueryType
  DEFINE  originURL       STRING
  DEFINE  ind             INTEGER

  # Delegate requires query string
  IF query.getLength()==0 THEN
    CALL req.sendTextResponse(400,"Bad request","Delegate query string is missing")
    DISPLAY "ERROR (DoDelegate) : Query is missing"
    RETURN
  END IF

  # Delegate provides originURL from query string parameter named 'url'
  LET ind = query.search("name","url")
  IF ind<=0 THEN
    CALL req.sendTextResponse(400,"Bad request","Delegate query URL is missing")
    DISPLAY "ERROR (DoDelegate) : Query URL is missing"
    
  ELSE

    # Delegate origin URL 
    LET originURL = query[ind].VALUE
    DISPLAY "DoDelegate : originURL=",originURL
    
    # Remove url param
    CALL query.deleteElement(1)

    IF originURL.getIndexOf(HTTPHelper.C_RESUME_URL,1)>1 THEN

      CALL DelegateResumeApp(req, baseURL, query, originURL)
      
    ELSE

      CALL DelegateAuthenticate(req, baseURL, query, originURL)   
        
    END IF
  END IF
END FUNCTION

#+
#+ Validate user credentials after HTML form post
#+  set cookie for application URL
#+  redirect browser to application URL
#+  or return error page 
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
#+ @param backURL URL to redirect user-agent when validated 
#+
PRIVATE
FUNCTION ValidateUser(req, baseURL, query, backURL)
  DEFINE  req         com.HttpServiceRequest
  DEFINE  baseURL     STRING  
  DEFINE  query       WSHelper.WSQueryType
  DEFINE  backURL     STRING
  DEFINE  p_user      STRING
  DEFINE  p_pwd       STRING
  DEFINE  p_connected BOOLEAN
  DEFINE  cookies     WSHelper.WSServerCookiesType
  
  # Retrieve data from HTML formular content
  CALL parseHTMLFormData( req.readFormEncodedRequest(TRUE) ) RETURNING p_user, p_pwd, p_connected

  # Check if user is authorized
  IF SSOUserFunctions.checkAuth (p_user, p_pwd) THEN

    # Create user cookie for application path 
    IF p_connected THEN
      LET cookies = SSOUserFunctions.createSession(p_user, CURRENT + COOKIE_KEEP, backURL)
    ELSE
      LET cookies = SSOUserFunctions.createSession(p_user, CURRENT + COOKIE_VALIDITY, backURL)
    END IF

    # Set cookie 
    CALL req.setResponseCookies(cookies)
    CALL req.setResponseHeader(HTTPHelper.C_HTTP_LOCATION, backURL)
    
    # Redirect to the initial application got via back
    CALL req.sendResponse(302,NULL)
    RETURN
  ELSE
    DISPLAY "ERROR (ValidateUser) : user not authorized"
  END IF

  # Return error page
  CALL HTTPHelper.sendErrorPage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?back="||util.strings.urlEncode(backUrl))
  
END FUNCTION

#+
#+ ReValidate user credentials after HTML relogin form post
#+  set relaystate valid entry to 1 if user is authenticated
#+  redirect browser to /ua/resume/sessionid?relaystate=xxx URL
#+  or return error page 
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
#+ @param relayId identifier if the application beeing re authenticated
#+
PRIVATE
FUNCTION ReValidateUser(req, baseURL, query, relayId)
  DEFINE  req         com.HttpServiceRequest
  DEFINE  baseURL     STRING  
  DEFINE  query       WSHelper.WSQueryType
  DEFINE  relayId     STRING
  DEFINE  p_user      STRING
  DEFINE  p_pwd       STRING
  DEFINE  p_connected BOOLEAN
  DEFINE  ua_session  STRING
  
  # Retrieve data posted from HTML formular content
  CALL HTTPHelper.parseHTMLFormData( req.readFormEncodedRequest(TRUE) ) RETURNING p_user, p_pwd, p_connected

  # Check if user is authorized
  IF SSOUserFunctions.checkAuth (p_user, p_pwd) THEN

    # Validate authenticated user with initial relaystate
    LET ua_session = SSOUserFunctions.validateRelayState(relayId, p_user) 

    IF ua_session IS NOT NULL THEN
      
      # User successfully re-logged, redirect user-agent to /ua/resume/sessionId to continue application
      CALL req.setResponseHeader(HTTPHelper.C_HTTP_LOCATION, baseURL||HTTPHelper.C_RESUME_URL||ua_session||"?relaystate="||relayId)
      CALL req.sendResponse(302, NULL)
      RETURN 
      
    END IF
    
  END IF        

  # Return error page
  CALL HTTPHelper.sendErrorPage(req, NULL)

END FUNCTION

#+
#+ Validate response after login or re-login page submission 
#+  by getting user + password as XForm data response
#+  and application URL in query string param name back
#+  or relogin state via query string param named relaystate
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
FUNCTION DoValidate(req, baseURL, query)
  DEFINE  req         com.HttpServiceRequest
  DEFINE  baseURL     STRING  
  DEFINE  query       WSHelper.WSQueryType
  DEFINE  ind         INTEGER

  # Check whether validation request (back present ?)
  LET ind = query.search("name","back")
  IF ind>0 THEN
    # Process initial user validation
    CALL ValidateUser(req, baseURL, query, query[ind].VALUE)
  ELSE  
    # Check whether re-login validation request (relaystate present ?)
    LET ind = query.search("name","relaystate")
    IF ind>0 THEN      
      # Process user re-login validation
      CALL ReValidateUser(req, baseURL, query, query[ind].VALUE)
    ELSE  
      # Error
      CALL HTTPHelper.sendErrorPage(req, NULL)
    END IF  
  END IF
  
END FUNCTION

#+
#+ Process /Prompt operation triggered when re-log button is clicked
#+  It Creates a relaystate entry to follow re-log workflow
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param baseURL server base URL (https://host:port/gas)
#+
#+ @param query current request decoded query string array
#+
FUNCTION DoPrompt(req, baseURL, query)
  DEFINE  req         com.HttpServiceRequest
  DEFINE  baseURL     STRING    
  DEFINE  query       WSHelper.WSQueryType
  DEFINE  ind         INTEGER
  DEFINE  prompt_id   STRING
  DEFINE  session_id  STRING
  DEFINE  timeout     INTERVAL SECOND(9) TO SECOND
  DEFINE  uuid        STRING

  # Ensure there is a query string
  IF query.getLength()==0 THEN
    CALL req.sendTextResponse(400,"Bad Request","Prompt query string is missing")
    DISPLAY "ERROR (Prompt) : Query is missing"
    RETURN
  END IF

  # Retrieve mandatory prompt_id (containing user in this case)
  LET ind = query.search("name","prompt")
  IF ind==0 THEN
    CALL req.sendTextResponse(400,"Bad Request","Prompt id is missing")
    DISPLAY "ERROR (Prompt) : id is missing"    
    RETURN
  ELSE
    LET prompt_id = query[ind].value
  END IF

  
  # Retrieve mandatory ua session 
  LET ind = query.search("name","session")
  IF ind==0 THEN
    CALL req.sendTextResponse(400,"Bad Request","Prompt session is missing")
    DISPLAY "ERROR (Prompt) : Session is missing"    
    RETURN
  ELSE
    LET session_id = query[ind].value
  END IF

  # Retrieve mandatory timeout
  LET ind = query.search("name","timeout")
  IF ind==0 THEN
    CALL req.sendTextResponse(400,"Bad Request","Prompt timeout is missing")
    DISPLAY "ERROR (Prompt) : Timeout is missing"    
    RETURN
  ELSE
    LET timeout = query[ind].value
  END IF

  # Create initial relay state for a short period 
  LET uuid = SSOUserFunctions.createRelayState(prompt_id, session_id, CURRENT + RELOGIN_TIME)
  
  # Start reauthentication page and send reponse to /Validate?relaystate operation 
  CALL HTTPHelper.SendRelogPage(req, baseURL||C_BASE_PATH||HTTPHelper.C_VALIDATE||"?relaystate="||uuid)
  
END FUNCTION

