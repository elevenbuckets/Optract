module.exports = {
    compilers: {
        solc:{
            version: '0.5.2',
            docker: true,
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        },
    },
    networks: {
        development: {
            // host: "172.17.0.2",  // use it for server in docker
            host: "127.0.0.1",  // use it for server in docker
            port: 8545,
            gas: 7000000,
            network_id: "*" // Match any network id
        }
    }
};
