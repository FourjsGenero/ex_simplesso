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

IMPORT com
IMPORT XML
IMPORT util

IMPORT FGL WSHelper

#+
#+ Constant helpers to set environment variable to ua proxy during delegate start
#+
PUBLIC CONSTANT C_X_FOURJS_HTTPS = "X-FourJs-Environment-Variable-HTTPS"
PUBLIC CONSTANT C_X_FOURJS_REMOTE_ADDR
    = "X-FourJs-Environment-Variable-REMOTE_ADDR"
PUBLIC CONSTANT C_X_FOURJS_ENVIRONMENT_ = "X-FourJs-Environment-"
PUBLIC CONSTANT C_X_FOURJS_ENVIRONMENT_PARAMETER_
    = "X-FourJs-Environment-Parameter-"
PUBLIC CONSTANT C_X_FOURJS_BOOTSTRAP
    = "X-FourJs-Environment-Parameter-Extra-BOOTSTRAP"
PUBLIC CONSTANT C_X_FOURJS_FGL_AUTO_LOGOUT_PROMPT_QUERY
    = "X-FourJs-Environment-FGL_AUTO_LOGOUT_PROMPT_QUERY"

#+
#+ HTTP response reason to indicate to dispatcher to start ua proxy after
#+  in a delegate response
#+
PUBLIC CONSTANT C_GENERO_INTERNAL_DELEGATE = "_GENERO_INTERNAL_DELEGATE_"

#+
#+ URL part name for Delegate operation
#+
PUBLIC CONSTANT C_DELEGATE = "Delegate"

#+
#+ URL part name for Prompt operation
#+
PUBLIC CONSTANT C_PROMPT = "Prompt"

#+
#+ URL part name for Validate operation
#+
PUBLIC CONSTANT C_VALIDATE = "Validate"

#+
#+ URL request to resume re-login
#+
PUBLIC CONSTANT C_RESUME_URL = "/ua/resume/"

PUBLIC CONSTANT C_HTTP_PRAGMA = "Pragma"

PUBLIC CONSTANT C_HTTP_CACHE_CONTROL = "Cache-Control"

PUBLIC CONSTANT C_HTTP_LOCATION = "Location"

PUBLIC CONSTANT C_HTTP_NO_CACHE = "no-cache"

PUBLIC CONSTANT C_HTTP_NO_STORE = "no-store"

PUBLIC CONSTANT C_COOKIE_NAME = "4jsCookie"

PUBLIC CONSTANT C_CONTENT_TYPE = "Content-Type"

PUBLIC CONSTANT C_TEXT_HTML = "text/html"

#+
#+ Extract HTML Formular data after a POST submit
#+
#+ @param query the POST content raw data
#+
#+ @return username, password and keep_connected
#+
PUBLIC FUNCTION parseHTMLFormData(query)
    DEFINE query STRING
    DEFINE ind INTEGER
    DEFINE tkz base.StringTokenizer
    DEFINE q_user, q_pwd STRING
    DEFINE keepConnected BOOLEAN
    DEFINE token STRING

    LET keepConnected = FALSE
    LET tkz = base.StringTokenizer.create(query, "&")
    WHILE tkz.hasMoreTokens()
        LET token = tkz.nextToken()
        LET ind = token.getIndexOf("=", 1)

        CASE token.subString(1, ind - 1)

            WHEN "userName"
                LET q_user = token.subString(ind + 1, token.getLength())

            WHEN "password"
                LET q_pwd = token.subString(ind + 1, token.getLength())

            WHEN "check"
                LET keepConnected = TRUE

        END CASE
    END WHILE

    RETURN q_user, q_pwd, keepConnected
END FUNCTION

#+
#+ Display the HTML welcome page
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param login_url URL to submit the POST formular
#+
PUBLIC FUNCTION SendWelcomePage(req, login_url)
    DEFINE req com.HttpServiceRequest
    DEFINE login_url STRING
    DEFINE htmlContent STRING
    DEFINE htmlDom xml.DomDocument
    DEFINE node xml.DomNode
    DEFINE list xml.DomNodeList

    LET htmlDom = xml.DomDocument.Create()
    #Load the HTML as xml document
    CALL htmlDom.load("../res/SSOLogin.xhtml")

    # Set Form action url to login url
    LET list = htmlDom.selectByXPath("//FORM[@NAME='login']", NULL)
    LET node = list.getItem(1)
    CALL node.setAttribute("action", login_url)

    #Save it to String
    LET htmlContent = htmlDom.saveToString()

    #Set content type to html and then display the page for being able to login
    CALL req.setResponseHeader("Content-Type", "text/html")
    CALL req.sendTextResponse(200, "Welcome, please login", htmlContent)

END FUNCTION

#+
#+ Display the HTML re-log page
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param login_url URL to submit the POST formular
#+ @param username Name of user to be re-logged
#+
PUBLIC FUNCTION SendRelogPage(req, login_url, username)
    DEFINE req com.HttpServiceRequest
    DEFINE login_url STRING
    DEFINE username STRING
    DEFINE htmlContent STRING
    DEFINE htmlDom xml.DomDocument
    DEFINE node xml.DomNode
    DEFINE list xml.DomNodeList

    LET htmlDom = xml.DomDocument.Create()

    #Load the HTML as xml document
    CALL htmlDom.load("../res/SSORelogin.xhtml")

    # Set Form action url to login url
    LET list = htmlDom.selectByXPath("//FORM[@NAME='relog']", NULL)
    LET node = list.getItem(1)
    CALL node.setAttribute("action", login_url)

    # Set username value
    IF username IS NOT NULL THEN
        LET list = htmlDom.selectByXPath("//input[@name='userName']", NULL)
        LET node = list.getItem(1)
        CALL node.setAttribute("value", username)
    END IF

    #Save it to String
    LET htmlContent = htmlDom.saveToString()

    #Set content type to html and then display the page for being able to login
    CALL req.setResponseHeader("Content-Type", "text/html")
    CALL req.sendTextResponse(200, "Welcome, please re-log", htmlContent)

END FUNCTION

#+
#+ Display the HTML expired page
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param login_url URL to submit the POST formular
#+
PUBLIC FUNCTION SendExpirePage(req, login_url)
    DEFINE req com.HttpServiceRequest
    DEFINE login_url STRING
    DEFINE htmlContent STRING
    DEFINE htmlDom xml.DomDocument
    DEFINE node xml.DomNode
    DEFINE list xml.DomNodeList

    LET htmlDom = xml.DomDocument.Create()

    #Load the HTML as xml document
    CALL htmlDom.load("../res/SSOExpire.xhtml")

    # Set Form action url to login url
    LET list = htmlDom.selectByXPath("//FORM[@NAME='expire']", NULL)
    LET node = list.getItem(1)
    CALL node.setAttribute("action", login_url)

    #Save it to String
    LET htmlContent = htmlDom.saveToString()

    #Set content type to html and then display the page for being able to login
    CALL req.setResponseHeader("Content-Type", "text/html")
    CALL req.sendTextResponse(200, NULL, htmlContent)

END FUNCTION

#+
#+ Display the HTML error page
#+
#+ @param req current HTTPServiceRequest instance
#+
#+ @param login_url URL to submit the POST formular
#+
PUBLIC FUNCTION SendErrorPage(req, login_url)
    DEFINE req com.HttpServiceRequest
    DEFINE login_url STRING
    DEFINE htmlContent STRING
    DEFINE htmlDom xml.DomDocument
    DEFINE node xml.DomNode
    DEFINE list xml.DomNodeList

    LET htmlDom = xml.DomDocument.Create()

    #Load the HTML as xml document
    CALL htmlDom.load("../res/SSOError.xhtml")

    IF login_url IS NOT NULL THEN
        # Set Form action url to login url
        LET list = htmlDom.selectByXPath("//FORM[@NAME='error']", NULL)
        LET node = list.getItem(1)
        CALL node.setAttribute("action", login_url)
    END IF
    #Save it to String
    LET htmlContent = htmlDom.saveToString()

    #Set content type to html and then display the page for being able to login
    CALL req.setResponseHeader("Content-Type", "text/html")
    CALL req.sendTextResponse(200, NULL, htmlContent)

END FUNCTION
