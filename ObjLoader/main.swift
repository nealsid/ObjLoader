//
//  main.swift
//  ObjLoader
//
//  Created by Neal Sidhwaney on 9/5/20.
//  Copyright © 2020 Neal Sidhwaney. All rights reserved.
//

import Foundation
import CoreImage
import AppKit

var objFile = CommandLine.arguments[1]

let objFileData = try! String(contentsOfFile: objFile)

let lines = objFileData.split(separator: "\r\n")

struct Vertex {
    let x, y, z : Float
    
    init (_ floats : [Float]) {
        x = floats[0]
        y = floats[1]
        z = floats[2]
    }
}

struct VertexTexture {
    let u, v : Float
    init (_ floats : [Float]) {
        u = floats[0]
        v = floats[1]
    }
}

struct VertexNormal {
    let x, y, z : Float
    init (_ floats : [Float]) {
        x = floats[0]
        y = floats[1]
        z = floats[2]
    }
}

var vertices : [Vertex] = []
var vertexTextures : [VertexTexture] = []
var vertexNormals : [VertexNormal] = []

for x in lines {
    if x.starts(with: "#") {
        continue
    }
    
    let parseFloats = { (line : String.SubSequence) -> [Float] in
        return line.split(separator: " ").dropFirst().map() { Float($0)! }
    }
    
    if x.starts(with: "v ") {
        vertices.append(Vertex(parseFloats(x)))
    }
    
    if x.starts(with: "vt ") {
        vertexTextures.append(VertexTexture(parseFloats(x)))
    }
    
    if x.starts(with: "vn ") {
        vertexNormals.append(VertexNormal(parseFloats(x)))
    }
}

print("\(vertices.count) vertices")
print("\(vertexTextures.count) vertex textures")
print("\(vertexNormals.count) vertex normals")

let camera = (0.0,0.0,0.0)
let focalLength : Float = 50.0
let imageWidth = 1024
let imageHeight = 768
let imageCenter = (0.0, 0.0, -focalLength)
let imageUL = (-imageWidth / 2, imageHeight / 2, -focalLength)
let imageUR = (imageWidth / 2, imageHeight / 2, -focalLength)
let imageLL = (-imageWidth / 2, -imageHeight / 2, -focalLength)
let imageLR = (imageWidth / 2, -imageHeight / 2, -focalLength)

// for every pixel, calculate vector from camera to pixel. use that vector to test for intersection.
var outputbitmap : [UInt8] = [UInt8](repeating: 0, count: 4 * imageWidth * imageHeight)

func dp(_ v1 : (Float, Float, Float), _ v2 : (Float, Float, Float)) -> Float {
    return v1.0 * v2.0 + v1.1 * v2.1 + v1.2 * v2.2
}

// Render a sphere with center (0, 0, 2 * - focalLength) with radius 25
let radius : Float = 125.0
var tangents : Int = 0
var twoPointIntersections : Int = 0
for i in 0..<imageWidth {
    for j in 0..<imageHeight {
        let cameraToPixelVector = (Float(i - imageWidth / 2), Float(j - imageHeight / 2), -focalLength)
        let cameraToPixelLength = sqrt(dp(cameraToPixelVector, cameraToPixelVector))
        let c2punit = (cameraToPixelVector.0 / cameraToPixelLength, cameraToPixelVector.1 / cameraToPixelLength, cameraToPixelVector.2 / cameraToPixelLength)
        
        let eyeCenterDiff = (Float(0 - 0), Float(0 - 0), Float(0 - (2.75 * -focalLength)))
        let a = -dp(c2punit, eyeCenterDiff)
        let delta = pow(a, 2) - (dp(eyeCenterDiff, eyeCenterDiff) - pow(radius, 2))
        let firstByte = j * imageWidth * 4 + i * 4
        if delta < 0 {
            outputbitmap[firstByte] = 0
            outputbitmap[firstByte + 1] = 0
            outputbitmap[firstByte + 2] = 0
            outputbitmap[firstByte + 3] = 0
            continue
        }
        
        if delta == 0 {
            tangents += 1
        } else {
            twoPointIntersections += 1
        }
        outputbitmap[firstByte] = 255
        outputbitmap[firstByte + 1] = 255
        outputbitmap[firstByte + 2] = 255
        outputbitmap[firstByte + 3] = 255
    }
}

var outputImage : CIImage

var imageData : Data? = nil
// Unsafe because we're storing a pointer to outputbitmap's underlying bytes, but outputbitmap is constant at this point
// so it shouldn't be reallocated or moved 🤞
outputbitmap.withUnsafeBytes() { (buffer : UnsafeRawBufferPointer) in
    imageData = Data(buffer: buffer.bindMemory(to: UInt8.self))
}

outputImage = CIImage(bitmapData: imageData!, bytesPerRow: imageWidth * 4, size: CGSize(width: imageWidth, height: imageHeight), format: CIFormat.RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))

let v : NSBitmapImageRep = NSBitmapImageRep(ciImage: outputImage)
let imgData = v.representation(using: NSBitmapImageRep.FileType.png, properties: [NSBitmapImageRep.PropertyKey : Any]())
try! imgData?.write(to: URL(fileURLWithPath: "foo.png"))
print ("\(tangents) tangents and \(twoPointIntersections) through-sphere intersections.")
