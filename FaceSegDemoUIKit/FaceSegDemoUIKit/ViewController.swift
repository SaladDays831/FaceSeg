import UIKit
import FaceSeg

extension UIImage {
    func atSizeScaled(_ size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        self.draw(in: CGRect.init(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

class ViewController: UIViewController {
    
    private let faceSeg = FaceSeg()
    
    private let imageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        imageView.backgroundColor = .lightGray
        imageView.contentMode = .scaleAspectFit
        
        faceSeg.delegate = self
        faceSeg.debugImage(from: UIImage(resource: .demoImg))
        
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 300).isActive = true
    }


}

extension ViewController: FaceSegDelegate {
    func didFinishProcessingImage(_ image: UIImage?) {
        imageView.image = image
    }
    
    func didFinishProcessingImages(_ images: [UIImage]?) {
        
    }
    
    func didFinishWithError(_ errorString: String) {
        
    }
}
