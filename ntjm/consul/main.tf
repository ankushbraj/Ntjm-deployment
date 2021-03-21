
terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~>2.0"
    }
  }
}

provider "consul" {
  address    = "127.0.0.1:8500"
  datacenter = "dc1"
}

##################################################################################
# Create Policies for Dev/Test/Prod env
##################################################################################

resource "consul_keys" "production" {

  key {
    path  = "production/configuration/"
    value = ""
  }

  key {
    path  = "production/state/"
    value = ""
  }
}

resource "consul_keys" "development" {

  key {
    path  = "development/configuration/"
    value = ""
  }

  key {
    path  = "development/state/"
    value = ""
  }
}


resource "consul_keys" "test" {

  key {
    path  = "test/configuration/"
    value = ""
  }

  key {
    path  = "test/state/"
    value = ""
  }
}

resource "consul_acl_policy" "production" {
  name  = "production"
  rules = <<-RULE
    key_prefix "production" {
      policy = "write"
    }

    session_prefix "" {
      policy = "write"
    }
    RULE
}

resource "consul_acl_policy" "development" {
  name  = "development"
  rules = <<-RULE
    key_prefix "development" {
      policy = "write"
    }

    key_prefix "production/state" {
      policy = "read"
    }

    session_prefix "" {
      policy = "write"
    }

    RULE
}


resource "consul_acl_policy" "test" {
  name  = "test"
  rules = <<-RULE
    key_prefix "test" {
      policy = "write"
    }

    key_prefix "production/state" {
      policy = "read"
    }

    key_prefix "development/state" {
      policy = "read"
    }    

    session_prefix "" {
      policy = "write"
    }

    RULE
}

resource "consul_acl_token" "prod-admin" {
  description = "token for prod-admin"
  policies    = [consul_acl_policy.production.name]
}

resource "consul_acl_token" "dev-admin" {
  description = "token for dev-admin"
  policies    = [consul_acl_policy.development.name]
}


resource "consul_acl_token" "test-admin" {
  description = "token for test-admin"
  policies    = [consul_acl_policy.test.name]
}

##################################################################################
# Consul Token Outputs 
##################################################################################

output "admin_token_accessor_id" {
  value = consul_acl_token.prod-admin.id
}

output "dev_token_accessor_id" {
  value = consul_acl_token.dev-admin.id
}

output "test_token_accessor_id" {
  value = consul_acl_token.test-admin.id
}
