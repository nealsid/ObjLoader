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

func dp(_ v1 : (Float, Float, Float), _ v2 : (Float, Float, Float)) -> Float {
    return v1.0 * v2.0 + v1.1 * v2.1 + v1.2 * v2.2
}

func sv(_ v1 : (Float, Float, Float), _ m : (Float)) -> (Float, Float, Float) {
    return (v1.0 * m, v1.1 * m, v1.2 * m)
}

func subv(_ v1 : (Float, Float, Float), _ v2 : (Float, Float, Float)) -> (Float, Float, Float) {
    return addv(v1, negv(v2))
}

func addv(_ v1 : (Float, Float, Float), _ v2 : (Float, Float, Float)) -> (Float, Float, Float) {
    return (v1.0 + v2.0, v1.1 + v2.1, v1.2 + v2.2)
}

func unitv(_ v : (Float, Float, Float)) -> (Float, Float, Float) {
    let vlength = vlen(v)
    return sv(v, 1 / vlength)
}

func negv(_ v: (Float, Float, Float)) -> (Float, Float, Float) {
    return (-v.0, -v.1, -v.2)
}

func vlen(_ v: (Float, Float, Float)) -> Float {
    return sqrt(dp(v, v))
}

let focalLength : Float = 25.0
let imageWidth = 101
let imageHeight = 101
let imageUL = (-imageWidth / 2, imageHeight / 2, focalLength)
let imageUR = (imageWidth / 2, imageHeight / 2, focalLength)
let imageLL = (-imageWidth / 2, -imageHeight / 2, focalLength)
let imageLR = (imageWidth / 2, -imageHeight / 2, focalLength)

// for every pixel, calculate vector from camera to pixel. use that vector to test for intersection.
var outputbitmap : [UInt8] = [UInt8](repeating: 0, count: 4 * imageWidth * imageHeight)

// Render a sphere with center (0, 0, 0) with radius 25
let circleCenter : (Float, Float, Float) = (0, 0, 0)
let radius : Float = 20
let radiusSquared : Float = pow(radius, 2)
let camera : (Float, Float, Float) = (0, 0, 50)
let cameraDirection : (Float, Float, Float) = (0, 0, -1)
var tangents : Int = 0
var twoPointIntersections : Int = 0
let pointLight : (Float, Float, Float) = (0, 30,20)

for i in 0..<imageWidth {
    for j in 0..<imageHeight {
        let cameraToPixelVector = subv((Float(i - imageWidth / 2), Float(imageHeight / 2 - j), camera.2 - focalLength), camera)
        let c2punit = unitv(cameraToPixelVector)
        
        let eyeCenterDiff = subv(camera, circleCenter)
        let a = -dp(c2punit, eyeCenterDiff)
        let delta = pow(a, 2) - (dp(eyeCenterDiff, eyeCenterDiff) - radiusSquared)

        let firstByte = j * imageWidth * 4 + i * 4
        if delta < 0 {
            outputbitmap[firstByte] = 0
            outputbitmap[firstByte + 1] = 0
            outputbitmap[firstByte + 2] = 0
            outputbitmap[firstByte + 3] = 255
            continue
        }

        let sqrtdelta = sqrt(delta)
        
        let d = (a + sqrtdelta, a - sqrtdelta)
        print("intersection parameter values for (\(i), \(j))")
        print("\(d.0) / \(d.1)")
        let p : (Float, Float, Float) = addv(camera, sv(c2punit, d.0))
        let q : (Float, Float, Float) = addv(camera, sv(c2punit, d.1))
//        print("first point of intersection: (\(String(p1.0)), \(String(p1.1)), \(String(p1.2)))")
//        print("second point of intersection: (\(String(p2.0)), \(String(p2.1)), \(String(p2.2)))")
        print("Point of intersection: (\(String(p.0)), \(String(p.1)), \(String(p.2)))")
        print("Point of intersection: (\(String(q.0)), \(String(q.1)), \(String(q.2)))")
        let cam2P = subv(p, camera)
        let cam2Q = subv(q, camera)
        let pdist = vlen(cam2P)
        let qdist = vlen(cam2Q)
        
        var spherePoint : (Float, Float, Float)
        
        if pdist < qdist {
            spherePoint = p
        } else {
            spherePoint = q
        }
        
        var normalAtIntersection : (Float, Float, Float) = subv(spherePoint, circleCenter)
        let pointLightVector = unitv(subv(pointLight, spherePoint))
        print("pointlight vector: (\(String(pointLightVector.0)), \(String(pointLightVector.1)), \(String(pointLightVector.2)))")
        print("normal at intersection: (\(String(normalAtIntersection.0)), \(String(normalAtIntersection.1)), \(String(normalAtIntersection.2)))")
        normalAtIntersection = unitv(normalAtIntersection)
        var intensityMultipler = dp(pointLightVector, normalAtIntersection)
        print("Intensity Multiplier: \(intensityMultipler)")
        if intensityMultipler <= 0 {
            intensityMultipler = 0.01 // implies normal is in opposite direction of point light vector and shouldn't be illuminated
        } else {
            intensityMultipler /= dp(pointLightVector, pointLightVector) // distance correction for square of distance
        }
        
        if delta == 0 {
            tangents += 1
        } else {
            twoPointIntersections += 1
        }
        
        if i == 462 && j == 411 {
            outputbitmap[firstByte] = 0
            outputbitmap[firstByte + 1] = 255
            outputbitmap[firstByte + 2] = 0
            outputbitmap[firstByte + 3] = 255

        } else {
            outputbitmap[firstByte] = UInt8(255 * intensityMultipler)
            outputbitmap[firstByte + 1] = UInt8(255 * intensityMultipler)
            outputbitmap[firstByte + 2] = 255
            outputbitmap[firstByte + 3] = 255
        }
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
