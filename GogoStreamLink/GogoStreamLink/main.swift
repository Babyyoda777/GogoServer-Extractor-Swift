import Foundation
import SwiftSoup
import CommonCrypto


struct StreamingUrl: Hashable, Identifiable, Codable {
    var id = UUID()
    
    var url: URL?
    var isM3U8: Bool?
    var quality: String?
}

let baseUrl = "https://gogoanime3.co"

func extractSources(from url: URL) async throws -> [StreamingUrl]? {
        var request = URLRequest(url: url)
        request.setValue(baseUrl, forHTTPHeaderField: "Referer")
        
        let (data, _) = try await URLSession.shared.data(for: request)
            
        guard let responseString = String(data: data, encoding: .utf8) else {
            print("An error occured while fetching streaming URLs. (2)")
            return nil
        }
                        
        let keyData = "37911490979715163134003223491201"
        let secondKeyData = "54674138327930866480207815084989"
        let ivData = "3134003223491201"
        
        let keys = (key: keyData, secondKey: secondKeyData, iv: ivData)
        
        var encryptedParams = String(responseString.split(separator: "data-value=\"")[1].split(separator: "\"><")[0]).aesDecrypt(key: keys.key, iv: keys.iv)
        
        let encrypt = encryptedParams?.split(separator: "&")[0]
        
        guard let encrypt = encrypt else {
            print("An error occured while fetching streaming URLs. Encrypt is nil.)")
            return nil
        }
        
        guard let newEncryptParams = String(data: Data(encrypt.utf8), encoding: .utf8)?.aesEncrypt(key: keys.key, iv: keys.iv) else {
            print("An error occured while fetching streaming URLs. New encrypted parameters are nil.)")
            return nil
        }
        
        encryptedParams = encryptedParams?.replacingOccurrences(of: "\(encrypt)", with: newEncryptParams)

        guard let encryptedParams = encryptedParams else {
            print("An error occured while fetching streaming URLs. Encrypted parameters are nil.)")
            return nil
        }
                
        guard let encryptedDataRequestUrl = URL(string: "https://playtaku.online/encrypt-ajax.php?id=\(encryptedParams)&alias=\(encrypt)") else {
            print("An error occured while fetching streaming URLs. Encrypted data request URL is broken. (6)")
            print("https://playtaku.online/encrypt-ajax.php?" + encryptedParams)
            return nil
        }
                
        var encryptedDataRequest = URLRequest(url: encryptedDataRequestUrl)
        
        encryptedDataRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        encryptedDataRequest.setValue(url.absoluteString, forHTTPHeaderField: "Referer")
        
        let (encryptedData, _) = try await URLSession.shared.data(for: encryptedDataRequest)
        
        let parsedData = try JSONDecoder().decode(GogoanimeSourceData.self, from: encryptedData)
        let decryptedData = parsedData.data.aesDecrypt(key: keys.secondKey, iv: keys.iv)
        
        guard let decryptedData = decryptedData?.data(using: .utf8) else {
            print("An error occured while fetching streaming URLs. Decrypted data is nil.")
            return nil
        }
        
        let parsedDecryptedData = try JSONDecoder().decode(Source.self, from: decryptedData)

        var sources = [StreamingUrl]()

        if parsedDecryptedData.source?[0].file?.contains(".m3u8") ?? false, let source = parsedDecryptedData.source?[0] {
            guard let fileUrl = URL(string: source.file ?? "") else {

                return nil
            }
            
            let (resResult, _) = try await URLSession.shared.data(from: fileUrl)
            
            guard let stringResResult = String(data: resResult, encoding: .utf8) else {

                return nil
            }
            
            let resolutions = stringResResult.components(separatedBy: .newlines).map {
                if $0.contains("EXT-X-STREAM-INF") {
                    return $0.components(separatedBy: "RESOLUTION=")[1].components(separatedBy: ",")[0]
                }
                
                return ""
            }.filter { !$0.isEmpty }
                                    
            for resolution in resolutions {
                let index = parsedDecryptedData.source?[0].file?.lastIndex(of: "/")
                
                guard let index = index else {
                    print("An error occured while fetching streaming URLs. Index is nil.")
                    return nil
                }
                
                let quality = resolution.components(separatedBy: "x")[1]
                guard let stringResolutionUrl = parsedDecryptedData.source?[0].file?[..<index] else {
                    print("An error occured while fetching streaming URLs. Initial resolution URL is nil.")
                    return nil
                }
                
                guard let indexOfResolution = stringResResult.components(separatedBy: .newlines).firstIndex(where: { $0.contains(resolution) && !$0.contains(".m3u8") }) else {
                    print("An error occured while fetching streaming URLs. Index of resolution is nil.")
                    return nil
                }

                guard let resolutionUrl = URL(string: stringResolutionUrl + "/" + stringResResult.components(separatedBy: .newlines)[indexOfResolution + 1]) else {
                    print("An error occured while fetching streaming URLs. Resolution URL is nil.")
                    print(stringResolutionUrl + "/" + stringResResult.components(separatedBy: .newlines)[indexOfResolution])
                    return nil
                }
                                
                sources.append(StreamingUrl(
                    url: resolutionUrl,
                    isM3U8: resolutionUrl.absoluteString.contains(".m3u8"),
                    quality: quality + "p")
                )
            }
        }
        
        return sources
    }

// Example usage
let exampleURL = URL(string: "https://embtaku.pro/embedplus?id=MTg0MTQx&token=nATKgOihzt2RU7oNOwmJ2A&expires=1710422162")!




struct GogoanimeSourceData: Codable, Hashable {
    var data: String
}

struct Source: Codable {
    var source: [SourceFile]?
    var sourceBk: [SourceFile]?
    
    enum CodingKeys: String, CodingKey {
        case source
        case sourceBk = "source_bk"
    }
}

struct SourceFile: Codable {
    let file: String?
    let label: String?
    let type: String?
}

do {
    let sources = try await extractSources(from: exampleURL)
    print(sources ?? "No streaming URLs found")
} catch {
    print("Error fetching streaming URLs: \(error)")
}
