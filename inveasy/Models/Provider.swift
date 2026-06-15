//
//  Provider.swift
//  inveasy
//

import Foundation

/// One entry returned by `GET {hub}/api/v1/providers`. The `baseURL` is the
/// host used for every subsequent catalog and order call.
struct Provider: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    let name: String
    let baseURL: URL
    let logoURL: URL?
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case baseURL = "baseUrl"
        case logoURL = "logoUrl"
        case description
    }
}
