import ArgumentParser

@main
struct SwiftMarket: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftmarket",
        abstract: "SwiftMarket CLI — buy and sell anything",
        subcommands: [
            CreateUserCommand.self,
            UsersCommand.self,
            UserCommand.self,
            UserListingsCommand.self,
            ListingsCommand.self,
            ListingCommand.self,
            PostCommand.self,
            DeleteCommand.self
        ]
    )
}