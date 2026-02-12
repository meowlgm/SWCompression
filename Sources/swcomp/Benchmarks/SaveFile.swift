// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct SaveFile: Codable {

    struct Run: Codable {

        var uuid: UUID
        var metadata: BenchmarkMetadata
        var results: [BenchmarkResult]

    }

    var formatVersion = 2
    var runs: [Run]

    init(_ oldSaveFile: OldSaveFile) {
        var d = [UUID: [BenchmarkResult]]()
        for run in oldSaveFile.runs {
            d[run.metadataUUID] = (d[run.metadataUUID] ?? [BenchmarkResult]()) + run.results
        }

        self.runs = [Run]()
        for (uuid, results) in d {
            guard let metadata = oldSaveFile.metadatas[uuid]
                else { swcompExit(.benchmarkOldFormatNoUUIDMetadata(uuid)) }
            self.runs.append(Run(uuid: uuid, metadata: metadata, results: results.sorted(by: { $0.id < $1.id })))
        }
    }

    static func load(from path: String) throws -> SaveFile {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try decoder.decode(SaveFile.self, from: data)
    }

}
