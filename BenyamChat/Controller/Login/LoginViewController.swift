//
//  LoginViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 27.11.2022.
//

import UIKit
import Firebase
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let textField = UITextField()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .continue
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.placeholder = "Enter email"
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        textField.leftViewMode = .always
        textField.backgroundColor = .clear
        return textField
    }()
    
    private let passwordField: UITextField = {
        let textField = UITextField()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.placeholder = "Enter password"
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        textField.leftViewMode = .always
        textField.backgroundColor = .clear
        textField.isSecureTextEntry = true
        return textField
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleToFill
        return imageView
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .link
        button.setTitle("Log In", for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let googleSignInButton = GIDSignInButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log in"
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegisterButton))
        
        emailField.delegate = self
        passwordField.delegate = self
        
        
        //Add subview
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(googleSignInButton)
        
        loginButton.addTarget(self, action: #selector(didTapLoginButton), for: .touchUpInside)
        googleSignInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 5
        imageView.frame = CGRect(x: (scrollView.width - size) / 2,
                                 y: 20,
                                 width: size * 0.83,
                                 height: size)
        
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                  y: emailField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        loginButton.frame = CGRect(x: 30,
                                  y: passwordField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        googleSignInButton.frame = CGRect(x: 30,
                                  y: loginButton.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
    }
    

    @objc private func didTapRegisterButton(){
        let vc = RegisterViewController()
        vc.title = "Register account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func didTapLoginButton(){
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLoginError()
            return
            
        }
        spinner.show(in: view)
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {[weak self] authResult, error in
            guard let result = authResult, let strongSelf = self, error == nil else {
                print("Error loggin in to user with email: \(email)")
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss(animated: true)
            }
            
            let user = result.user
            print("Logged in user: \(user)")
            
            let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: {result in
                switch result{
                case .success(let userData):
                    guard let userData = userData as? [String: Any],
                          let firstName = userData["first_name"] as? String,
                          let lastName = userData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print("Failed to fetch user name: \(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            
            strongSelf.navigationController?.dismiss(animated: true)
        })
    }
    
    private func alertUserLoginError(){
        let alert = UIAlertController(title: "Not enough information",
                                      message: "Please enter all information to log in.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func signIn(){
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)

        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) {[weak self] user, error in
            
            guard let strongSelf = self, error == nil else {
                return
            }
            
            guard let authentication = user?.authentication,
                let idToken = authentication.idToken else {
                return
            }
            
            guard let email = user?.profile?.email,
                  let firstName = user?.profile?.givenName,
                  let lastName = user?.profile?.familyName else {
                return
            }
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists{
                    let chatUser = ChatAppUser(firstName: firstName,
                                               lastName: lastName,
                                               email: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completeion: { success in
                        if success{
                            
                            if ((user?.profile?.hasImage) != nil){
                                guard let url = user?.profile?.imageURL(withDimension: 200) else{
                                    return
                                }
                                
                                URLSession.shared.dataTask(with: url, completionHandler: {data, _, _ in
                                    guard let data = data else {
                                        return
                                    }
                                    let fileName = chatUser.profileImageFileName
                                    StorageManager.shared.uploadProfileImage(with: data, fileName: fileName, completion: {result in
                                        switch result{
                                        case .success(let downloadURL):
                                            print(downloadURL)
                                        case .failure(let error):
                                            print("Storage manager error: \(error)")
                                        }
                                    })
                                }).resume()
                            }
                        }
                    })
                }
            })
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: { authResult, error in
                guard authResult != nil , error == nil else {
                    print("Failed to sign in with google credentials")
                    return
                }
                
                print("Succesfully signed in with Google")
                
                UserDefaults.standard.set(email, forKey: "email")
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        }
    }
}


extension LoginViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField{
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField{
            didTapLoginButton()
        }
        
        return true
    }
}
