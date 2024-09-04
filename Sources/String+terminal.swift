extension String {
    var commandStyle: String {
        "\u{1B}[1m\(self)\u{1B}[0m"
    }
    
    var messageStyle: String {
        "\u{1B}[1;34m\(self)\u{1B}[0m"
    }
}
