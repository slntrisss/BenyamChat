//
//  ChatModels.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 21.12.2022.
//

import Foundation
import CoreLocation
import MessageKit

struct Message: MessageType{
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

struct Sender:SenderType{
    var photoURL: String
    var senderId: String
    var displayName: String
}

struct Media: MediaItem{
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem{
    var location: CLLocation
    var size: CGSize
}

extension MessageKind{
    var messageTypeDescriprion: String{
        switch self{
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
}
