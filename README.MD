# Deployment of AliCloud CEN

## Description

### Note:

This Terraform module deploys an AliCloud (CEN)[https://www.alibabacloud.com/help/en/cloud-enterprise-network/latest/what-is-cloud-enterprise-network#concept-2090845] instance. It then interconnects two existing VPCs, one of which must be deployed in a region in China over the newly deployed CEN. Optionally, it connects two existing VPCs to an existing CEN; if this is the case the CEN is expected to already have two transit routers deployed and with an existing peering betweem themselves. One of the transit routers must be deployed in China

This Terraform module:

- Creates an AliCloud CEN instance and transit routers in the China and Global regions that will be interconnected and attached the existing VPCs
- Creates the required route table artifacts to achieve communication between the VPCs across the regions
- CEN Inter-region connection pricing defaults to Pay-by-data-transfer
- Optionally, it creates a CEN Bandwidth package, or uses an existing CEN Bandwidth package if one is specified


## Prerequisites

1. [Terraform v0.13+](https://www.terraform.io/downloads.html) - execute terraform files


## Providers

| Name | Version |
|------|---------|
| <a name="provider_alicloud"></a> [alicloud](https://registry.terraform.io/providers/aliyun/alicloud/latest) | ~> 1.203.0 |


## Procedures for Running This Module
### 1. Authenticating to AliCloud

Set environment variables ALICLOUD_ACCESS_KEY and ALICLOUD_SECRET_KEY:

  ``` shell
  export ALICLOUD_ACCESS_KEY="anaccesskey"
  export ALICLOUD_SECRET_KEY="asecretkey"
  ```


### 3. Applying Terraform configuration

```hcl

terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      version = "~> 1.203.0"
      configuration_aliases = [alicloud.china, alicloud.global]
    } 
}
}

provider "alicloud" {
  alias = "china"
  region = "cn-beijing"
}

provider "alicloud" {
  alias = "global"
  region = "ap-southeast-1"
}

module "cen" {
    providers = {
      alicloud.china = alicloud.china
      alicloud.global = alicloud.global
    }
    source = "github.com/jocortems/alicloud_cen_deployment"
    ali_china_region                                    = var.ali_china_region                                          # Optional. Required if creating new CEN instance (cen_name is provided). Region ID where the existing VPC in China is deployed 
    ali_global_region                                   = var.ali_global_region                                         # Optional. Required if creating new CEN instance (cen_name is provided). Region ID where the existing VPC in Global is deployed 
    china_vpc_cidr                                      = var.china_vpc_cidr                                            # Required. Prefix must be /25 or shorter and have the third /27 subnet available
    global_vpc_cidr                                     = var.global_vpc_cidr                                           # Required. Prefix must be /25 or shorter and have the third /27 subnet available
    china_vpc_id                                        = var.china_vpc_id                                              # Required.  
    global_vpc_id                                       = var.global_vpc_id                                             # Required.
    cen_instance_id                                     = var.cen_instance_id                                           # Optional. Specify if using existing CEN. Conflicts with cen_name
    cen_name                                            = var.cen_name                                                  # Optional. Specify if need to create new CEN. One of cen_instance_id or cen_name is required
    global_vswitch_cidr_master_cen_tr                   = var.global_vswitch_cidr_master_cen_tr                         # Required. vSwitch that will be created in the master zone of the Transit Router CEN in Global Region
    global_vswitch_cidr_slave_cen_tr                    = var.global_vswitch_cidr_slave_cen_tr                          # Required. vSwitch that will be created in the slave zone of the Transit Router CEN in Global Region
    china_vswitch_cidr_master_cen_tr                    = var.china_vswitch_cidr_master_cen_tr                          # Required. vSwitch that will be created in the master zone of the Transit Router CEN in China Region
    china_vswitch_cidr_slave_cen_tr                     = var.china_vswitch_cidr_slave_cen_tr                           # Required. vSwitch that will be created in the slave zone of the Transit Router CEN in China Region
    cen_global_geo                                      = var.cen_global_geo                                            # Optional. Required if creating new CEN instance (cen_name is provided). Valid values are "Asia-Pacific", "North-America", "Europe" and "Australia"
    cen_bandwidth_type                                  = var.cen_bandwidth_type                                        # Optional. Defaults to DataTransfer
    cen_bandwidth_package_name                          = var.cen_bandwidth_package_name                                # Optional. If specified creates a bandwidth package for the CEN. Conflicts with cen_bandwidth_package_id. Leave blank if using existing CEN
    cen_bandwidth_package_id                            = var.cen_bandwidth_package_id                                  # Optional. Specifies an existing bandwidth package to use with CEN. Conflicts with cen_bandwidth_package_name. Leave blank if using existing CEN
    cen_bandwidth_package_bandwdith                     = var.cen_bandwidth_package_bandwdith                           # Optional. Default 100Mbps. Only needed if cen_bandwidth_package_name is specified
    cen_bandwidth_limit                                 = var.cen_bandwidth_limit                                       # Optional. Default 100Mbps. Needed if either cen_bandwidth_package_name or cen_bandwidth_package_id are specified. Must be less than or equal to cen_bandwidth_package_bandwdith if creating a bandwidth package, or less than the existing bandwidth package bandwidth if using an existing one  
    cen_bandwidth_package_period                        = var.cen_bandwidth_package_period                              # Optional. Default 1 month. Only needed if cen_bandwidth_package_name is specified      
    cen_transit_router_peer_attachment_bandwidth_limit  = var.cen_transit_router_peer_attachment_bandwidth_limit        # Optional. Defaults to 100Mbps. This value is used regardless of whether a bandwidth package is used or not 
}

```

### Execute

```shell
terraform init
terraform apply --var-file=<terraform.tfvars>
````

## **Disclaimer**:

The material embodied in this software/code is provided to you "as-is" and without warranty of any kind, express, implied or otherwise, including without limitation, any warranty of fitness for a particular purpose. In no event shall the Aviatrix Inc. be liable to you or anyone else for any direct, special, incidental, indirect or consequential damages of any kind, or any damages whatsoever, including without limitation, loss of profit, loss of use, savings or revenue, or the claims of third parties, whether or not Aviatrix Inc. has been advised of the possibility of such loss, however caused and on any theory of liability, arising out of or in connection with the possession, use or performance of this software/code.