# Configuration

Change the configuration workflow from a closure based workflow to a direct `struct` which carries the properties which are then applied to the `URLRequest` when ever it's created.

Supply a default implementation which is applied automatically as a default parameter value when the user does not supply one.

This should cover the configurable properties of the `URLRequest` which are not otherwise set by the engine.