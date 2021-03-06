//
//  EditVC.swift
//  SocialNet
//
//  Created by Agent X on 2/6/18.
//  Copyright © 2018 Andrii Halabuda. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase

class EditVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var userPic: CustomImageView!
    @IBOutlet weak var usernameTextField: CustomTextField!
    @IBOutlet weak var nameTextField: CustomTextField!
    @IBOutlet weak var bioTextField: CustomTextField!
    
    var imagePicker: UIImagePickerController!
    var imageSelected = false

    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        
        self.usernameTextField.delegate = self
        self.nameTextField.delegate = self
        self.bioTextField.delegate = self
        
        getUserData()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // Dismiss when return btn pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        usernameTextField.resignFirstResponder()
        nameTextField.resignFirstResponder()
        bioTextField.resignFirstResponder()
        return true
    }
    
    @IBAction func addImageTapped(_ sender: AnyObject) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        
        if let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.editedImage)] as? UIImage {
            userPic.image = image
            imageSelected = true
        } else {
            print("Image wasn't selected")
        }
        uploadProfileImg()
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func uploadProfileImg() {
        
        guard let img = userPic.image, imageSelected == true else {
            print("An image must be selected")
            return
        }
        
        if let imgData = img.jpegData(compressionQuality: 0.2) {
            
            let imgUid = NSUUID().uuidString
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            DataService.ds.REF_USER_IMAGES.child(imgUid).putData(imgData, metadata: metadata) { (metadata, error) in
                
                if error != nil {
                    print("Unable to upload image to Firebasee storage")
                    
                } else {
                    
                    print("Successfully uploaded image to Firebase storage")
                    
                    DataService.ds.REF_USER_IMAGES.child(imgUid).downloadURL(completion: { (url, error) in
                        if let err = error {
                            debugPrint(err.localizedDescription)
                        } else {
                            let downloadURL = url?.absoluteString
                            
                            if let url = downloadURL {
                                self.updateUserPicUrl(imgUrl: url)
                            }
                        }
                    })
                    
//                    let downloadURL = metadata?.downloadURL()?.absoluteString
//
//                    if let url = downloadURL {
//                        self.updateUserPicUrl(imgUrl: url)
//                    }
                }
            }
        }
    }
    
    func updateUserPicUrl(imgUrl: String) {
        
        let userPicUrl: Dictionary<String, String> = [
            
            "userPicUrl": imgUrl
        ]
        let firebaseProfileImage = DataService.ds.REF_USER_CURRENT
        firebaseProfileImage.updateChildValues(userPicUrl)
        
        imageSelected = false
    }
    
    @IBAction func backBtnTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneBtnTapped(_ sender: Any) {
        
        guard let username = usernameTextField.text, username != "" else {
            print("Username must be entered")
            return
        }
        
        guard let name = nameTextField.text, name != "" else {
            print("Name must be entered")
            return
        }
        
        guard let bio = bioTextField.text, bio != "" else {
            print("Bio must be entered")
            return
        }
        
        let childUpdates = [
            
            "/username": usernameTextField.text! as AnyObject,
            "/name": nameTextField.text! as AnyObject,
            "/bio": bioTextField.text! as AnyObject
        ]
        
        DataService.ds.REF_USER_CURRENT.updateChildValues(childUpdates)
        
        performSegue(withIdentifier: Segues.toProfile.rawValue, sender: nil)
        self.view.endEditing(true)
    }
    
    func getUserData() {
        
        let ref = DataService.ds.REF_USER_CURRENT
        DispatchQueue.main.async {
            ref.observe(.value, with: { (snapshot) in
                
                let value = snapshot.value as? NSDictionary
                let username = value?["username"] as? String ?? ""
                let name = value?["name"] as? String ?? ""
                let bio = value?["bio"] as? String ?? ""
                
                self.usernameTextField.text = username
                self.nameTextField.text = name
                self.bioTextField.text = bio
                
                print("N:" + name)
                print("UN:" + username)
                print("B:" + bio)
            })
        }
    }

 

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
