local config = {

    sql = {
        host = "192.168.1.125",
        port = 3306,
        database = "skynet",
        user = "root",
        password = "brucedamensqlpw",
    },

    redis = {
        host = "192.168.1.125",
        port = 6379,
        db   = 1,
        auth = "brucedamenredispw",
    }
}

return config