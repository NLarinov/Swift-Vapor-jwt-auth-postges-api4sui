//
//  AvatarMigrationSwift.swift
//  testProject
//
//  Created by Николай Ткачев on 17/02/2025.
//

import FluentPostgresDriver

struct AddAvatarToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("avatar", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("avatar")
            .update()
    }
}
