import Foundation
import SwiftSoup
import SwiftUI
import Combine 


class Turkish123: ObservableObject, SourcesObject {
    @Published var id = "Turkish"
    @Published var info: Details?
    @Published var SearchResults: [Card] = []
    @Published var Trending: [Card] = []
    @Published var streamurl: URL?
    func info(id: String){
        let urlString = "https://turkish123.ac/\(id)"
        getHTML(urlString: urlString) { result in
            switch result {
            case .success(let htmlString):
                do {
                    
                    let doc = try SwiftSoup.parse(htmlString)
                    let img = try doc.select("div.thumb img").first()?.attr("src") ?? ""
                    let about = try doc.select("p.f-desc").text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = try doc.select("div.mvic-desc h1").text()
                    let lastEp = try Int((doc.select("a.episodi").last()?.text().components(separatedBy: CharacterSet.decimalDigits.inverted).joined())!) ?? 1
                    //   let released = try doc.select(".anime_info_body_bg .type").eq(3).text()
                    // let genre = try doc.select(".anime_info_body_bg .type").eq(2).text()
                    let episodes = Array(1...lastEp)
                    let passedurl = urlString.last == "/" ? String(urlString.dropLast()) : urlString
                    let seriesdetails = Details(id: name, name: name, img: img, about: about, episodes: episodes, url: passedurl, released: nil, genre: nil)
                    
                    
                    
                    DispatchQueue.main.async {
                        self.info = seriesdetails
                        
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
        
    }
    
    func getStream(episodeurl: String, episodenumber: Int) async throws -> String? {
        
        guard let url = URL(string: "\(episodeurl)-episode-\(episodenumber)") else {
            print("Invalid URL")
            return ""
        }
        
        let html = try String(contentsOf: url)
        let doc = try SwiftSoup.parse(html)
        
        let contentElement = try doc.select("div.movieplay")
        let jsSnippet = try contentElement.select("script").toString()
        if let urlStartIndex = jsSnippet.range(of: "https://tukipasti.com")?.lowerBound,
           let urlEndIndex = jsSnippet.range(of: "\"", range: urlStartIndex..<jsSnippet.endIndex)?.lowerBound {
            let extractedURL = String(jsSnippet[urlStartIndex..<urlEndIndex])
            let html2 = try String(contentsOf: URL(string: extractedURL)!)
            let src = try SwiftSoup.parse(html2)
            let scripts = try src.select("script")
            
            var streamurl = ""
            // Loop through each script tag to find the variable assignment
            for script in scripts {
                // Get the script content
                let scriptContent = try script.html()
                let variableName = "urlPlay"
                // Check if the script contains the variable assignment
                if scriptContent.contains("\(variableName) =") {
                    // Extract the value assigned to the variable
                    if let urlPlayValue = scriptContent
                        .split(separator: "\n")
                        .first(where: { $0.contains("\(variableName) =") })?
                        .split(separator: "=").last?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "';")) {
                        streamurl.append(urlPlayValue)
                        DispatchQueue.main.async{
                            self.streamurl = URL(string: urlPlayValue)
                        }
                    }
                    else{
                        print("error")
                    }
                }
            }
            return streamurl
        }
        return nil
    }
    
    func search(query: String) {
        guard let url = URL(string: "https://turkish123.ac/?s=\(query)") else {
            print("Invalid URL")
            return
        }
        
        do {
            let html = try String(contentsOf: url)
            let doc = try SwiftSoup.parse(html)
            
            let contentElements = try doc.select("div.ml-item")
            var results = [Card]()
            
            for contentElement in contentElements {
                let url = try contentElement.select("a.jt").attr("href")
                let cover = try contentElement.select("img").attr("src")
                let title = try contentElement.select("span.mli-info").text()
                let id = url.removingPattern(pattern: "https://turkish123\\.ac/")
                let card = Card(id: id, url: url, name: title, img: cover)
                results.append(card)
            }
            
            DispatchQueue.main.async {
                self.SearchResults = results
            }
        } catch {
            print("Error parsing website: \(error)")
        }
    }
    
    func trending(){
        guard let url = URL(string: "https://turkish123.ac/genre/history/") else {
            print("Invalid URL")
            return
        }
        
        do {
            let html = try String(contentsOf: url)
            let doc = try SwiftSoup.parse(html)
            let contentElements = try doc.select("div.ml-item")
            var results = [Card]()
            
            for contentElement in contentElements {
                let url = try contentElement.select("a.jt").attr("href")
                let cover = try contentElement.select("img").attr("src")
                let title = try contentElement.select("span.mli-info").text()
                let id = url.removingPattern(pattern: "https://turkish123\\.ac/")
                let card = Card(id: id, url: url, name: title, img: cover)
                results.append(card)
            }
            
            DispatchQueue.main.async {
                
                if results.isEmpty {
                    print("No trending movies found.")
                } else {
                    self.Trending = results
                }
            }
        } catch {
            print("Error parsing website: \(error)")
        }
    }
    
}

extension String {
    func removingPattern(pattern: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: self.utf16.count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
        } catch {
            print("Error: \(error)")
            return self
        }
    }
}
