##Consul Config file for server.hcl

ui = true
server = true
bootstrap_expect = 1
datacenter = "dc1"
data_dir = "./data"

acl = {
    enabled = true
    default_policy = "allow"
    enable_token_persistence = true
}