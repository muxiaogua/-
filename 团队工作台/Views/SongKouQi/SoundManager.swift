//
//  SoundManager.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import Foundation
import Combine
import AVFoundation

/// 高品质禅意声学引擎：精准模拟布包木槌击打中空木鱼（Temple Block / Slit Drum）声学物理模型
final class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    @Published var isMuyuMuted: Bool = false
    @Published var isIncenseMuted: Bool = false
    @Published var volume: Float = 0.35 // 整体音量降低约60%，柔和舒适不刺耳
    
    // 预加载各材质专属声学数据
    private var cachedPlayers: [MuyuMaterial: AVAudioPlayer] = [:]
    
    // 紫檀真实录音专用多通道播放池（支持快速连击不中断）
    private var zitanPlayerPool: [AVAudioPlayer] = []
    private var zitanPoolIndex: Int = 0
    
    // 沉香真实录音专用多通道播放池（支持快速连击不中断）
    private var chenxiangPlayerPool: [AVAudioPlayer] = []
    private var chenxiangPoolIndex: Int = 0
    
    // 白玉真实录音专用多通道播放池（承载原紫檀经典录音，支持快速连击不中断）
    private var baiyuPlayerPool: [AVAudioPlayer] = []
    private var baiyuPoolIndex: Int = 0
    
    // 烧香午间放松专属背景音乐播放器 (3种香分别对应3首舒缓禅音，无缝循环)
    private var incenseBGMPlayers: [IncenseType: AVAudioPlayer] = [:]
    private var currentIncensePlayer: AVAudioPlayer? = nil
    @Published var isIncenseMusicPlaying: Bool = false
    @Published var activeIncenseType: IncenseType? = nil
    
    private init() {
        preloadAllSounds()
        preloadIncenseMusic()
    }
    
    private func preloadIncenseMusic() {
        let musicFiles: [IncenseType: String] = [
            .sandalwood: "incense_sandalwood",
            .aloeswood: "incense_aloeswood",
            .wormwood: "incense_wormwood"
        ]
        
        for (type, filename) in musicFiles {
            var musicData: Data? = nil
            if let url = Bundle.main.url(forResource: filename, withExtension: "wav") {
                musicData = try? Data(contentsOf: url)
            }
            if musicData == nil {
                let localPath = "放松/\(filename).wav"
                if FileManager.default.fileExists(atPath: localPath) {
                    musicData = try? Data(contentsOf: URL(fileURLWithPath: localPath))
                }
            }
            
            if let data = musicData, let player = try? AVAudioPlayer(data: data) {
                player.numberOfLoops = -1 // 无缝无限循环
                player.volume = self.volume * 0.75 // 柔和背景音量
                player.prepareToPlay()
                incenseBGMPlayers[type] = player
            }
        }
    }
    
    private func preloadAllSounds() {
        // 1. 优先加载紫檀新录音（/Users/apple/Desktop/新录音 8.m4a 原声）
        initZitanAudioPool()
        
        // 2. 优先加载卡通木鱼真实录音（原声）
        initChenxiangAudioPool()
        
        // 3. 优先加载白玉真实录音（原紫檀经典录音）
        initBaiyuAudioPool()
        
        // 4. 加载其他材质声学引擎
        for mat in MuyuMaterial.allCases {
            if mat == .redSandalwood && !zitanPlayerPool.isEmpty {
                continue
            }
            if mat == .cartoonMuyu && !chenxiangPlayerPool.isEmpty {
                continue
            }
            if mat == .whiteJade && !baiyuPlayerPool.isEmpty {
                continue
            }
            let wavData = generateAcousticWav(for: mat)
            if let player = try? AVAudioPlayer(data: wavData) {
                player.volume = self.volume
                player.prepareToPlay()
                cachedPlayers[mat] = player
            }
        }
    }
    
    private func initZitanAudioPool() {
        zitanPlayerPool.removeAll()
        
        // 查找项目 Bundle 或工程目录下的 muyu_zitan.wav
        var zitanData: Data? = nil
        if let url = Bundle.main.url(forResource: "muyu_zitan", withExtension: "wav") {
            zitanData = try? Data(contentsOf: url)
        }
        
        if zitanData == nil {
            let localPath = "放松/muyu_zitan.wav"
            if FileManager.default.fileExists(atPath: localPath) {
                zitanData = try? Data(contentsOf: URL(fileURLWithPath: localPath))
            }
        }
        
        if let data = zitanData {
            for _ in 0..<5 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.volume = self.volume * 0.75
                    player.prepareToPlay()
                    zitanPlayerPool.append(player)
                }
            }
        }
    }
    
    private func initChenxiangAudioPool() {
        chenxiangPlayerPool.removeAll()
        
        var chenxiangData: Data? = nil
        if let url = Bundle.main.url(forResource: "muyu_chenxiang", withExtension: "wav") {
            chenxiangData = try? Data(contentsOf: url)
        }
        
        if chenxiangData == nil {
            let localPath = "放松/muyu_chenxiang.wav"
            if FileManager.default.fileExists(atPath: localPath) {
                chenxiangData = try? Data(contentsOf: URL(fileURLWithPath: localPath))
            }
        }
        
        if let data = chenxiangData {
            for _ in 0..<5 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.volume = self.volume
                    player.prepareToPlay()
                    chenxiangPlayerPool.append(player)
                }
            }
        }
    }
    
    private func initBaiyuAudioPool() {
        baiyuPlayerPool.removeAll()
        
        var baiyuData: Data? = nil
        if let url = Bundle.main.url(forResource: "muyu_baiyu", withExtension: "wav") {
            baiyuData = try? Data(contentsOf: url)
        }
        
        if baiyuData == nil {
            let localPath = "放松/muyu_baiyu.wav"
            if FileManager.default.fileExists(atPath: localPath) {
                baiyuData = try? Data(contentsOf: URL(fileURLWithPath: localPath))
            }
        }
        
        if let data = baiyuData {
            for _ in 0..<5 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.volume = self.volume * 0.75
                    player.prepareToPlay()
                    baiyuPlayerPool.append(player)
                }
            }
        }
    }
    
    // MARK: - 敲木鱼音效播放
    func playMuyuSound(material: MuyuMaterial) {
        guard !isMuyuMuted else { return }
        
        if material == .redSandalwood && !zitanPlayerPool.isEmpty {
            let player = zitanPlayerPool[zitanPoolIndex]
            zitanPoolIndex = (zitanPoolIndex + 1) % zitanPlayerPool.count
            player.stop()
            player.currentTime = 0
            player.volume = self.volume * 0.85
            player.play()
            return
        }
        
        if material == .whiteJade && !baiyuPlayerPool.isEmpty {
            let player = baiyuPlayerPool[baiyuPoolIndex]
            baiyuPoolIndex = (baiyuPoolIndex + 1) % baiyuPlayerPool.count
            player.stop()
            player.currentTime = 0
            player.volume = self.volume * 0.75
            player.play()
            return
        }
        
        if material == .cartoonMuyu && !chenxiangPlayerPool.isEmpty {
            let player = chenxiangPlayerPool[chenxiangPoolIndex]
            chenxiangPoolIndex = (chenxiangPoolIndex + 1) % chenxiangPlayerPool.count
            player.stop()
            player.currentTime = 0
            player.volume = self.volume * 0.85
            player.play()
            return
        }
        
        if let player = cachedPlayers[material] {
            player.stop()
            player.currentTime = 0
            player.volume = self.volume * 0.85
            player.play()
        } else {
            let wavData = generateAcousticWav(for: material)
            if let player = try? AVAudioPlayer(data: wavData) {
                player.volume = self.volume * 0.85
                player.play()
                cachedPlayers[material] = player
            }
        }
    }
    
    // MARK: - 烧香午间放松背景音乐控制
    func playIncenseBGM(type: IncenseType) {
        guard !isIncenseMuted else { return }
        
        // 如果当前正在播放其他香型，先停止旧的
        if let current = currentIncensePlayer, current.isPlaying && activeIncenseType != type {
            current.stop()
        }
        
        if let player = incenseBGMPlayers[type] {
            player.currentTime = 0
            player.volume = self.volume * 0.75
            player.play()
            currentIncensePlayer = player
            activeIncenseType = type
            isIncenseMusicPlaying = true
        }
    }
    
    func stopIncenseBGM() {
        currentIncensePlayer?.stop()
        currentIncensePlayer = nil
        activeIncenseType = nil
        isIncenseMusicPlaying = false
    }
    
    func switchIncenseBGM(to type: IncenseType) {
        guard isIncenseMusicPlaying else { return }
        playIncenseBGM(type: type)
    }
    
    // MARK: - 物理声学算法合成（彻底摒除响板啪啪声、鼓边尖锐声与大鼓轰鸣）
    private func generateAcousticWav(for material: MuyuMaterial) -> Data {
        let sampleRate: Double = 44100.0
        
        switch material {
        case .redSandalwood:
            // 1. 紫檀老木：标准空心圆木鱼（Temple Block / Slit Drum）
            // 特征：布包木槌击打（音头软化无毛刺）、圆润、沉敛、克制、纯正中空木腔“笃”声
            let duration: Double = 0.17
            let numSamples = Int(sampleRate * duration)
            var samples = [Int16](repeating: 0, count: numSamples)
            let f0 = 252.0 // 经典寺院空心木鱼腔体谐振基频
            
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                
                // 布包木槌软起音包络（Soft Mallet Attack）：平滑升起，无高频啪啪杂音
                let attack = t < 0.0045 ? (0.5 * (1.0 - cos(.pi * (t / 0.0045)))) : 1.0
                
                // 木腔衰减包络：快速收敛、沉敛克制，不产生大鼓低频轰鸣
                let decay = exp(-t * 19.5)
                
                // 空心木腔主共鸣模态 (Helmholtz + Slit drum mode)
                let mainCavity = sin(2.0 * .pi * f0 * t) * 0.88
                
                // 木质内壁微弱二次谐振（迅速衰减）
                let innerWall = sin(2.0 * .pi * (f0 * 1.88) * t) * 0.14 * exp(-t * 50.0)
                
                // 实体木身共振基底（温暖圆润的木质感）
                let woodBody = sin(2.0 * .pi * (f0 * 0.72) * t) * 0.10 * exp(-t * 35.0)
                
                let sampleFloat = (mainCavity + innerWall + woodBody) * attack * decay
                let clamped = max(-1.0, min(1.0, sampleFloat * 0.65))
                samples[i] = Int16(clamped * 32767.0)
            }
            return createWavData(samples: samples, sampleRate: Int32(sampleRate))
            
        case .cartoonMuyu:
            // 2. 卡通木鱼：清雅空灵、温润通透木鱼音
            let duration: Double = 0.20
            let numSamples = Int(sampleRate * duration)
            var samples = [Int16](repeating: 0, count: numSamples)
            let f0 = 330.0
            
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let attack = t < 0.0035 ? (0.5 * (1.0 - cos(.pi * (t / 0.0035)))) : 1.0
                let decay = exp(-t * 16.5)
                
                let mainTone = sin(2.0 * .pi * f0 * t) * 0.85
                let overtone = sin(2.0 * .pi * (f0 * 1.92) * t) * 0.18 * exp(-t * 40.0)
                let woodWarmth = sin(2.0 * .pi * (f0 * 0.65) * t) * 0.08 * exp(-t * 30.0)
                
                let sampleFloat = (mainTone + overtone + woodWarmth) * attack * decay
                let clamped = max(-1.0, min(1.0, sampleFloat * 1.15))
                samples[i] = Int16(clamped * 32767.0)
            }
            return createWavData(samples: samples, sampleRate: Int32(sampleRate))
            
        case .emeraldJade:
            // 3. 翡翠：极品翡翠玉磬之音（金玉交鸣、清越通透、余音悠扬）
            let duration: Double = 0.32
            let numSamples = Int(sampleRate * duration)
            var samples = [Int16](repeating: 0, count: numSamples)
            let f0 = 520.0
            
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let attack = t < 0.0022 ? (0.5 * (1.0 - cos(.pi * (t / 0.0022)))) : 1.0
                let decay = exp(-t * 9.5)
                
                let h1 = sin(2.0 * .pi * f0 * t) * 0.78
                let h2 = sin(2.0 * .pi * (f0 * 2.14) * t) * 0.22 * exp(-t * 18.0)
                let h3 = sin(2.0 * .pi * (f0 * 3.32) * t) * 0.08 * exp(-t * 35.0)
                
                let sampleFloat = (h1 + h2 + h3) * attack * decay
                let clamped = max(-1.0, min(1.0, sampleFloat * 1.15))
                samples[i] = Int16(clamped * 32767.0)
            }
            return createWavData(samples: samples, sampleRate: Int32(sampleRate))
            
        case .whiteJade:
            // 4. 白玉：羊脂白玉清鸣（珠落玉盘、清越温润玉磬声）
            let duration: Double = 0.32
            let numSamples = Int(sampleRate * duration)
            var samples = [Int16](repeating: 0, count: numSamples)
            let f0 = 720.0
            
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let attack = t < 0.0018 ? (0.5 * (1.0 - cos(.pi * (t / 0.0018)))) : 1.0
                let decay = exp(-t * 9.0)
                
                let h1 = sin(2.0 * .pi * f0 * t) * 0.82
                let h2 = sin(2.0 * .pi * (f0 * 2.0) * t) * 0.16 * exp(-t * 18.0)
                
                let sampleFloat = (h1 + h2) * attack * decay
                let clamped = max(-1.0, min(1.0, sampleFloat * 1.1))
                samples[i] = Int16(clamped * 32767.0)
            }
            return createWavData(samples: samples, sampleRate: Int32(sampleRate))
        }
    }
    
    // MARK: - 生成轻量 RIFF WAV 二进制数据
    private func createWavData(samples: [Int16], sampleRate: Int32) -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = Int32(samples.count * 2)
        let chunkSize = 36 + dataSize
        
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        data.append(contentsOf: "WAVE".utf8)
        
        data.append(contentsOf: "fmt ".utf8)
        let subchunk1Size: Int32 = 16
        let audioFormat: Int16 = 1 // PCM
        data.append(withUnsafeBytes(of: subchunk1Size.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        data.append(contentsOf: "data".utf8)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        samples.withUnsafeBytes { buffer in
            data.append(Data(buffer))
        }
        return data
    }
}
