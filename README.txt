HTTPClientLib
=============

A lightweight async/await HTTP library for Swift with a protocol-first public surface.

Protocol convenience overloads
------------------------------

The HTTPClient protocol includes convenience overloads (via protocol extension)
for common call patterns that omit nil body/header arguments:

- get(_ url: URL)
- post(_ url: URL)
- post(_ url: URL, body: RequestBody)
- post(_ url: URL, headers: [String: String])
- post(_ url: URL, formItems: [FormItem])
- put(_ url: URL)
- put(_ url: URL, body: RequestBody)
- put(_ url: URL, headers: [String: String])
- delete(_ url: URL)
- delete(_ url: URL, body: RequestBody)
- delete(_ url: URL, headers: [String: String])

For full usage examples and API details, see README.md.
