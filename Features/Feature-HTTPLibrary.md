# HTTP Library

Build a simple HTTP library which covers all the major methods of the protocol.

The intention is to provide a simple, re-usable HTTP implementation.

Include:
- GET
- POST
- PUT
- DELETE

The user should be able to provide optional configuration parameters to allow the customisation of the underlying `URLRequest`.

The user should be able to provide an optional `URLSession` to further customise the engine.

For each method, the user should be able to provide:
- A `URL`
- Optional headers

Each method should return the response details, including the status code and response text as optional `Data`.

For methods which support it, the user should be able to provide an optional text, `Data` or `Encodable` (for JSON) body.

`POST` should also have the ability to support multipart form-data.  This should be simplified to allow the user to supply form items which the engine would then convert for posting.

It should include such options as:
- `file`: Including a `URL` to the physical file to be uploaded
- `data`: Including the `Data` to be upload
- `property`: To support simple name/value pairs.

Each item should include `name`, optional `fileName` and optional `mimeType` fields.

