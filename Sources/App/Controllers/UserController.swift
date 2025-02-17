//
//  File.swift
//  
//
//  Created by Михаил Прозорский on 27.01.2025.
//

import Fluent
import Vapor
import JWTKit

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("auth")
        
        users.post("signup", use: createUser)
        users.post("signin", use: signIn)
                
        let protected = users.grouped(JWTMiddleware())
        
        protected.patch("addavatar", use: addAvatar)
        protected.get("avatar", use: getAvatar)
        
        protected.get("check", use: checkToken)
        protected.get("user", use: getUser)
        protected.delete("drop", use: deleteUser)
        protected.get("data", use: getData)
        protected.get("users", use: getUsers)
    }
    
    @Sendable
    func createUser(req: Request) async throws -> RegLogDTO {
        let input = try req.content.decode(UserCreateDTO.self)
        
        guard try await User.query(on: req.db)
                .filter(\.$username == input.username)
                .first() == nil else {
            throw Abort(.badRequest, reason: "Username is already taken")
        }
        
        let newUser = User(
            id: UUID(), // Генерируем новый UUID
            name: input.username,
            email: input.email,
            password: input.password,
            response: input.secretResponse,
            token: ""
        )
        
        newUser.reloadToken(token: try await getToken(req: req, user: newUser))
        try await newUser.save(on: req.db)
        return RegLogDTO(id: 1, token: newUser.token)
    }
    
    @Sendable
    func addAvatar(req: Request) async throws -> RegLogDTO {
        let payload = try req.auth.require(UserPayload.self)
        
        // Получаем пользователя
        guard let user = try await User.find(payload.userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }

        let input = try req.content.decode(AvatarDTO.self)

        guard let base64String = input.avatar.split(separator: ",").last,
              let _ = Data(base64Encoded: String(base64String)) else {
            return RegLogDTO(id: -1, token: "Avatar could not be added for this user.")
        }

        // Проверяем, был ли аватар ранее
        let message = user.avatar == nil ? "Avatar successfully added for this user." : "Avatar successfully updated for this user."

        // Обновляем аватар
        user.avatar = input.avatar
        try await user.save(on: req.db)

        return RegLogDTO(id: user.id?.hashValue ?? 0, token: message)
    }
    
    @Sendable
    func getAvatar(req: Request) async throws -> RegLogDTO {
        let payload = try req.auth.require(UserPayload.self)
        
        // Ищем пользователя
        guard let user = try await User.find(payload.userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }

        // Проверяем, есть ли аватар
        guard let avatar = user.avatar else {
            return RegLogDTO(id: -1, token: "This user does not have an avatar.")
        }

        return RegLogDTO(id: user.id?.hashValue ?? 0, token: avatar)
    }
    
    @Sendable
    func signIn(req: Request) async throws -> RegLogDTO {
        let input = try req.content.decode(UserSignInDTO.self)
        
        guard let user = try await User.query(on: req.db)
                .filter(\.$username == input.username)
                .filter(\.$password == input.password) // В реальном приложении пароли должны быть хэшированы
                .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        user.reloadToken(token: try await getToken(req: req, user: user))
        try await user.save(on: req.db)
        return RegLogDTO(id: user.id?.hashValue ?? 0, token: user.token)
    }
    
    @Sendable
    func checkToken(req: Request) async throws -> HTTPStatus {
        _ = try req.auth.require(UserPayload.self)
        return .ok
    }
    
    @Sendable
    func getUser(req: Request) async throws -> UserDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userID, on: req.db) else {
            throw Abort(.notFound)
        }
        return UserDTO(id: user.id?.uuidString ?? "", username: user.username, email: user.email)
    }
    
    @Sendable
    func deleteUser(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await user.delete(on: req.db)
        return .noContent
    }
    
    @Sendable
    func getData(req: Request) async throws -> RegLogDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userID, on: req.db) else {
            throw Abort(.notFound)
        }
        return RegLogDTO(id: 0, token: user.token) // 200 Ok
    }
    
    @Sendable
    func getUsers(req: Request) async throws -> [User] {
        try await User.query(on: req.db).all()
    }
    
    func getToken(req: Request, user: User) async throws -> String {
        let payload = UserPayload(userID: try user.requireID())
        return try req.jwt.sign(payload)
    }
}

struct UserCreateDTO: Codable {
    let username: String
    let password: String
    let email: String
    let secretResponse: String
}

struct UserSignInDTO: Codable {
    let username: String
    let password: String
}

struct UserDTO: Codable, Content {
    let id: String
    let username: String
    let email: String
}

struct AvatarDTO: Codable {
    let avatar: String
}
