RestLibrary [![Build Status](https://drone.io/github.com/Pajn/RestLibrary/status.png)](https://drone.io/github.com/Pajn/RestLibrary/latest)
===========

RestLibrary is a simple library for creating REST inspired APIs in Dart with ease.
It consists of a transport agnostic RestServer and a HttpTransport. Other transports
can be used but at this time only http is provided by default.

RestServer Features:
* GET, POST, PUT & DELETE support on routes
* Extended [JSEND](http://labs.omniti.com/labs/jsend) style responses with status code
* Add preprocessors for authorization or similar

HttpTransport Features:
* Serve static files
* Websocket upgrade request callback

Look at example and tests for usage instructions.
