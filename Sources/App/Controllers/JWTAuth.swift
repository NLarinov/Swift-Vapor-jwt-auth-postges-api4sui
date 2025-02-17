//
//  File.swift
//  
//
//  Created by Михаил Прозорский on 27.01.2025.
//

import Fluent
import Vapor
import JWT

struct JWTMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = req.headers.bearerAuthorization?.token else {
            print("❌ Missing Bearer Token")
            throw Abort(.unauthorized, reason: "Missing or invalid token")
        }

        do {
            let payload = try req.jwt.verify(token, as: UserPayload.self)
            print("✅ Token Verified: \(payload.userID)")
            req.auth.login(payload)
        } catch {
            print("❌ Token verification failed: \(error)")
            throw Abort(.unauthorized, reason: "Invalid token")
        }

        return try await next.respond(to: req)
    }
}

struct UserPayload: JWTPayload, Authenticatable {
    var userID: UUID
    var exp: ExpirationClaim

    init(userID: UUID) {
        self.userID = userID
        self.exp = .init(value: .distantFuture)
    }

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
