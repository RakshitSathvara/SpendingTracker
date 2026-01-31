//
//  AuthError.swift
//  SpendingTracker
//
//  Created by Rakshit on 31/01/26.
//

import Foundation
import FirebaseAuth

// MARK: - Auth Error

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case networkError
    case requiresRecentLogin
    case userDisabled
    case operationNotAllowed
    case tooManyRequests
    case invalidCredential
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .userNotFound:
            return "No account found with this email."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .requiresRecentLogin:
            return "Please sign in again to complete this action."
        case .userDisabled:
            return "This account has been disabled."
        case .operationNotAllowed:
            return "This operation is not allowed."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .invalidCredential:
            return "Invalid credentials. Please try again."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            return "Check the email format and try again."
        case .weakPassword:
            return "Use a stronger password with at least 6 characters."
        case .emailAlreadyInUse:
            return "Try signing in instead, or use a different email."
        case .userNotFound:
            return "Check the email address or create a new account."
        case .wrongPassword:
            return "Check your password and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .requiresRecentLogin:
            return "Sign out and sign in again before retrying."
        case .tooManyRequests:
            return "Wait a few minutes before trying again."
        default:
            return nil
        }
    }

    // MARK: - Firebase Error Conversion

    static func from(_ error: Error) -> AuthError {
        let nsError = error as NSError

        // Check if it's a Firebase Auth error
        guard nsError.domain == AuthErrorDomain,
              let errorCode = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown(error.localizedDescription)
        }

        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .networkError:
            return .networkError
        case .requiresRecentLogin:
            return .requiresRecentLogin
        case .userDisabled:
            return .userDisabled
        case .operationNotAllowed:
            return .operationNotAllowed
        case .tooManyRequests:
            return .tooManyRequests
        case .invalidCredential:
            return .invalidCredential
        default:
            return .unknown(error.localizedDescription)
        }
    }

    // MARK: - Equatable

    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.userNotFound, .userNotFound),
             (.wrongPassword, .wrongPassword),
             (.networkError, .networkError),
             (.requiresRecentLogin, .requiresRecentLogin),
             (.userDisabled, .userDisabled),
             (.operationNotAllowed, .operationNotAllowed),
             (.tooManyRequests, .tooManyRequests),
             (.invalidCredential, .invalidCredential):
            return true
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
