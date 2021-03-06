//
//  ProfileVC.swift
//  SocialNet
//
//  Created by Andrew Foster on 5/11/17.
//  Copyright © 2017 Andrii Halabuda. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import Firebase
import SwiftKeychainWrapper

class ProfileVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var usernameLbl: UILabel!
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var bioLbl: UILabel!
    @IBOutlet weak var userPic: CustomImageView!
    @IBOutlet weak var profileTableView: UITableView!
    
    var imagePicker: UIImagePickerController!
    static var imageCache: NSCache<NSString, UIImage> = NSCache()
    var imageSelected = false
    var userPicUrl: String!
    var posts = [Post]()
    var myPosts = [Post]()
    let myPostsReference = DataService.ds.REF_USER_CURRENT.child("/myPosts")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        
        profileTableView.delegate = self
        profileTableView.dataSource = self
        
        updateUI()
        getUserImageUrl()
        loadMyPosts()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        downloadProfilePic()
        loadMyPosts()
        
    }
    
    @IBAction func signOutTapped(_ sender: AnyObject) {
        
        let keychainResult = KeychainWrapper.standard.removeObject(forKey: KEY_UID)
        print("ID removed from keychain \(keychainResult)")
        try! Auth.auth().signOut()
        performSegue(withIdentifier: "toSignIn", sender: nil)
        
        self.view.endEditing(true)
    }
    
    @IBAction func backBtnPressed(_ sender: Any) {
        
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func editProfileBtnTapped(_ sender: Any) {
        
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
//                    let downloadURL = metadata?.downloadURL()?.absoluteString
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
    
    func downloadProfilePic(img: UIImage? = nil) {
        
        // Download User Image & handle errors
        DispatchQueue.main.async {
            if img != nil {
                
                self.userPic.image = img
                
            } else {
                
                let ref = Storage.storage().reference(forURL: self.userPicUrl)
                ref.getData(maxSize: 2 * 1024 * 1024, completion: { (data, error) in
                    
                    if error != nil {
                        print("Unable to download image from Firebase storage")
                        print("\(String(describing: error))")
                        self.userPic.image = UIImage(named: "noImage")
                        
                    } else {
                        
                        print("Image downloaded from Firebase storage")
                        if let imgData = data {
                            
                            if let img = UIImage(data: imgData) {
                                
                                self.userPic.image = img
                                // Add downloaded image to cache
                                ProfileVC.imageCache.setObject(img, forKey: self.userPicUrl as NSString)
                            }
                        }
                    }
                })
            }
        }
    }
    
    func updateUI() {
        
        let ref = DataService.ds.REF_USER_CURRENT
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            
            let value = snapshot.value as? NSDictionary
            let username = value?["username"] as? String ?? ""
            let name = value?["name"] as? String ?? ""
            let bio = value?["bio"] as? String ?? ""
//            let userPic = value?["userPicUrl"] as? String ?? ""
            
//            self.userPicUrl = userPic
            self.usernameLbl.text = username
            self.nameLbl.text = name
            self.bioLbl.text = bio
            
//            print("UPU:" + self.userPicUrl)
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func getUserImageUrl() {
        
        let ref = DataService.ds.REF_USER_CURRENT
        DispatchQueue.main.async {
            ref.observe(.value, with: { (snapshot) in
                
                let value = snapshot.value as? NSDictionary
                let userPic = value?["userPicUrl"] as? String ?? ""
                self.userPicUrl = userPic
                
                print("UPU:" + self.userPicUrl)
            })
        }
    }
    
    func loadMyPosts() {
//        let ref = DataService.ds.REF_POSTS
//        DispatchQueue.main.async {
//            
//            ref.observe(.value, with: { (snapshot) in
//                
//                // Fixes dublicate posts issue
//                self.posts = []
//                
//                if let snapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
//                    for snap in snapshot {
//                        print("SNAPSHOT: \(snap)")
//                        let key = snap.key
//                        let value = snap.value as? NSDictionary
//                        let username = value?["username"] as? String ?? ""
//                        
//                        print("GETUN:" , username)
//                        let post = Post(postKey: key, postData: value as! Dictionary<String, AnyObject>)
////                        self.posts.append(post)
//                        
//                        if self.currentUsername == username {
//                            print("EQUAL")
//                            let post = Post(postKey: key, postData: value as! Dictionary<String, AnyObject>)
//                            self.myPosts.append(post)
//                            print("myPOSTS:" , self.myPosts)
//                        }
//                    }
//                    
//                }
//                self.profileTableView.reloadData()
//            })
//            
//        }
        
        
        DataService.ds.REF_USER_CURRENT.child("/myPosts").queryOrdered(byChild: "timeStamp").observe(.value, with: { (snapshot) in
            
            // Fixes dublicate posts issue
            self.posts = []
            
            // Stores temporary data
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    print("SNAP: \(snap)")
                    if let postDict = snap.value as? Dictionary<String, AnyObject> {
                        let key = snap.key
                        let post = Post(postKey: key, postData: postDict)
                        self.posts.append(post)
                        print("Posts:", self.posts)
                    }
                }
            }
            self.profileTableView.reloadData()
        })
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let post = posts[indexPath.row]
        
        if let cell = profileTableView.dequeueReusableCell(withIdentifier: "profilePostCell") as? PostCell {
            
//            DispatchQueue.main.async {
//                if let img = ProfileVC.imageCache.object(forKey: post.imageUrl as NSString) {
//
//                    cell.configureCell(post: post, img: img)
//
//                } else {
//
//                    cell.configureCell(post: post)
//                }
//            }
            
            DispatchQueue.main.async {
                if let img = FeedVC.imageCache.object(forKey: post.imageUrl as NSString) , let pic = FeedVC.imageCache.object(forKey: post.userPicUrl as NSString) {
                    
                    cell.configureCell(post: post, img: img, pic: pic)
                } else {
                    
                    cell.configureCell(post: post)
                }
            }
            
            return cell
            
        } else {
            
            return PostCell()
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
