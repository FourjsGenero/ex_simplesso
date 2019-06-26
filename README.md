# SimpleSSOProvider Demo
SimpleSSOProvider is a sample implementation of Single Sign On (SSO) for Genero with support of re-login after a time of inactivity.

It prevents direct access to the application and ask the end user to enter a login and password.
Once connected, the end user does not need to enter any credentials for 24 hours. This duration can be adjusted in the source code.

As a demo, the session management is simple and manage sessions via a SQLite database.

## Prerequisities
- Genero Studio 3.10
- Genero Business Language 3.10
- Genero Application Server 3.10
- Genero Browser Client 1.00

## Project
It contains:
- a web service managing the Single Sign On using Genero Application Server (GAS) delegation. For any details about delegation, please refer to the Genero Application Server documentation.
- a demo configuration (ssodemo.xcf) to test the SSO
- a demo configuration (ssorelogdemo.xcf) to test the SSO with re-login after 10s of inactivity

## Test application
The test application is the standard FGL demo configured to go through the Simple SSO Service Provider.

You can use any other application. The key part is to add the **`<DELEGATE>`** tag in your xcf file. See _deployconfig/ssodemo.xcf_
```
<APPLICATION Parent="defaultgwc">
	<EXECUTION>
		<PATH>$(res.path.fgldir.demo)</PATH>
        <MODULE>demo</MODULE>
		<DELEGATE service="SimpleSSOServiceProvider"/>
	</EXECUTION>
</APPLICATION>
```

## Service
Web service configuration file _deployconfig/SimpleSSOServiceProvider.xcf_
```
<APPLICATION Parent="ws.default">
  <EXECUTION>
    <ENVIRONMENT_VARIABLE Id="FGLPROFILE">fglprofile</ENVIRONMENT_VARIABLE>
    <PATH>$(res.deployment.path)/bin</PATH>
    <MODULE>SSOService</MODULE>
  </EXECUTION>
</APPLICATION>
```

## How to compile and deploy from GST
- build the application (see **SimpleSSOServiceProvider** application node)
- start Genero Application Server
- deploy the applications (see deployment node **SimpleSSODemo**)

You can deploy the applications by uploading the gar file through the **Genero Identy Platform** from the GAS home page.
```
http://localhost:6394/demos.html
```
## How to test
Once GAS started and the applications deployed.

Start the demo application with url like:
```
http://<gas_server>:<gas_port>/ua/r/ssodemo
```
For example
```
http://localhost:6394/ua/r/ssodemo
```

Or the re-login demo application with url like:
```
http://<gas_server>:<gas_port>/ua/r/ssorelogdemo
```
For example
```
http://localhost:6394/ua/r/ssorelogdemo
```

## Disconnect (log off)
To disconnect when a permanent cookie has been set, add **disconnect=true** to the query string.
```
http://<gas_server>:<gas_port>/ua/r/ssodemo?disconnect=true
```
You are automatically redirected to the login page.

When the cookie has expired, you are redirected to the login page.

## Production recommendations
The demo is designed to convey single sign-on basics. Consider these recommendations when preparing for your production system.
- Function shown in this sample must be reviewed and adapted especially for it. We recommend you review these functions in detail before adapting them to your production environment.
- A production site would require another database than sqlite.
- Production sites requires the use of the HTTPS protocol rather than HTTP in order to avoid the transmission of clear data through the network.

For more details on the demo, please read ![README-extra](README-extra.md)