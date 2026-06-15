//
//  Page.swift
//  inveasy
//

import Foundation

/// Wraps a single-resource response: `{ "data": ... }`.
struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

/// Wraps a paginated list response: `{ "data": [...], "meta": { ... } }`.
struct PageEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let meta: PageMeta
}

struct PageMeta: Decodable, Hashable, Sendable {
    let total: Int
    let page: Int
    let perPage: Int
    let totalPages: Int
}
