//
//  ProfileModels.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 21.12.2022.
//

import Foundation

enum ProfileViewModelType{
    case info, logout
}

struct ProfileViewModel{
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> ())?
}
