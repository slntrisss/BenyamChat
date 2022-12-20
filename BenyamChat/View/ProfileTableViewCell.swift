//
//  ProfileTableViewCell.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 20.12.2022.
//

import UIKit

class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with model: ProfileViewModel){
        self.textLabel?.text = model.title
        switch model.viewModelType{
        case .info:
            self.textLabel?.textAlignment = .left
            self.selectionStyle = .none
        case .logout:
            self.textLabel?.textAlignment = .center
            self.textLabel?.textColor = .red
        }
    }

}
