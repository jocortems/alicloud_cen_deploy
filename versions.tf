terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      version = "~> 1.204.0"
      configuration_aliases = [alicloud.china, alicloud.global]
}
}
}