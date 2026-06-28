# HTTPEngine Library

* Favour Swift naming conventions for public facing functionality.
	* Make use of camel case for property names.
	* Avoid using seperators like \_.

## Technology Stack

* A Swift package
* Swift Testing as a preference
* async/await concurrency
* Minimal dependencies
* HTTP transport errors should be raised to the caller, doing otherwise could mask the underlying issue and make it more difficult for them to diagnose the actual issue.