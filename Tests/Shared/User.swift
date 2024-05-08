@testable import Cache
import Foundation

struct User: Codable, Equatable {
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

func == (lhs: User, rhs: User) -> Bool {
    lhs.firstName == rhs.firstName
        && lhs.lastName == rhs.lastName
}
