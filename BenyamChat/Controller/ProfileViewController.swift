//
//  ProfileViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 27.11.2022.
//

import UIKit
import FirebaseAuth
import GoogleSignIn
import SDWebImage

enum ProfileViewModelType{
    case info, logout
}

struct ProfileViewModel{
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> ())?
}

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

    var data = [ProfileViewModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            UserDefaults.standard.setValue(nil, forKey: "email")
            UserDefaults.standard.setValue(nil, forKey: "name")
            guard let strongSelf = self else{return}
            let actionSheet = UIAlertController(title: "",
                                                message: "Are you  sure you wan to log out?",
                                                preferredStyle: .actionSheet)
            
            actionSheet.addAction(UIAlertAction(title: "Log Out",
                                                style: .destructive, handler: {[weak self] _ in
                
                let firebaseAuth = Auth.auth()
                guard let strongSelf = self else{return}
                do{
                    try FirebaseAuth.Auth.auth().signOut()
                    try firebaseAuth.signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)
                    
                }catch let signOutError as NSError{
                    print("Failed to log out")
                    print("Error signing out: %@", signOutError)
                }
            }))
            
            actionSheet.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel,
                                                handler: nil))
            
            strongSelf.present(actionSheet, animated: true)
        }))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.tableHeaderView = createTableViewHeader()
    }
    
    func createTableViewHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_image.png"
        let path = "images/" + fileName
        let headerView = UIView()
        headerView.frame = CGRect(x: 0,
                                  y: 0,
                                  width: view.width,
                                  height: 300)
        let imageView = UIImageView(frame: CGRect(x: (view.width - 150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        headerView.addSubview(imageView)
        headerView.backgroundColor = .link
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.layer.borderWidth = 3
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.cornerRadius = imageView.width / 2
        imageView.layer.masksToBounds = true
        
        StorageManager.shared.downloadURL(for: path){ result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        }
        
        return headerView
    }

}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.configure(with: data[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}
