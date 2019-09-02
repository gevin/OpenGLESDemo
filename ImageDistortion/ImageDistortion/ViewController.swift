//
//  ViewController.swift
//  ImageDistortion
//
//  Created by GevinChen on 2019/9/2.
//  Copyright © 2019 GevinChen. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var glView: GLView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        glView.setupGL()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        glView.renderTexture()
    }


}

