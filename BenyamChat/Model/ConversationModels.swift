//
//  ConversationModels.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 21.12.2022.
//

import Foundation

struct Conversation{
    let id: String
    let name: String
    let otherUSerEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage{
    let date: String
    let message: String
    let isRead: Bool
}
