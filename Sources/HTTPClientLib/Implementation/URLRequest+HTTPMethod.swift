//
//  URLRequest+HTTPMethod.swift
//  HTTPClientLib
//
//  Created by Shane Whitehead on 30/6/2026.
//

import Foundation

internal extension URLRequest {
    
    var method: HTTPMethod? {
        get {
            guard let httpMethod else { return nil }
            return HTTPMethod(rawValue: httpMethod.uppercased())
        }
        
        set {
            httpMethod = newValue?.rawValue
        }
    }
}
