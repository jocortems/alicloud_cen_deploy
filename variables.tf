variable "ali_china_region" {
    type = string
    description = "Alibaba China Cloud Region Name"
}

variable "ali_global_region" {
    type = string
    description = "Alibaba Global Cloud Region Name"
}

variable "china_vpc_cidr" {
  type = string
  description = "CIDR used for the Aviatrix Transit VPC"  
}

variable "global_vpc_cidr" {
  type = string
  description = "CIDR of the Aviatrix Transit VPC in Global Region"
}

variable "china_vpc_id" {
  type = string
  description = "VPC ID of the Aviatrix Transit VPC in China Region"
}

variable "global_vpc_id" {
  type = string
  description = "VPC ID of the Aviatrix Transit VPC in Global Region"
}

variable "global_vswitch_cidr_master_cen_tr" {
  type = string
  description = "CIDR of the vSwitch in the Global Region that will connect to the master CEN transit router created in global region"
}

variable "global_vswitch_cidr_slave_cen_tr" {
  type = string
  description = "CIDR of the vSwitch in the Global Region that will connect to the slave CEN transit router created in global region"
}

variable "china_vswitch_cidr_master_cen_tr" {
  type = string
  description = "CIDR of the vSwitch in the China Region that will connect to the master CEN transit router created in China region"
}

variable "china_vswitch_cidr_slave_cen_tr" {
  type = string
  description = "CIDR of the vSwitch in the China Region that will connect to the slave CEN transit router created in China region"
}

variable "cen_instance_id" {
  type = string
  description = "If using an existing CEN, specify CEN Instance ID. If not provided, a new CEN will be created"
  default = null  
}

variable "cen_name" {
  type = string
  description = "Name assigned to the AliCloud CEN instance"  
  default = null
}

variable "cen_bandwidth_package_name" {
  type = string
  description = "If this variable is provided a new CEN Bandwidth package of type Prepaid will be created. Conflicts wtih cen_bandwidth_package_id"
  default = null
}

variable "cen_bandwidth_package_bandwdith" {
  type = number
  description = "Bandwidth allocated to the CEN bandwdith package to be created. Only needed if cen_bandwidth_package_name is specified"
  default = 100
}

variable "cen_bandwidth_limit" {
  type = number
  description = "Bandwidth allocated to the CEN from an existing CEN bandwidth package. Must be less than or equal to cen_bandwidth_package_bandwdith"
  default = 100
}

variable "cen_bandwidth_package_period" {
  type = number
  description = "CEN bandwidth package purchase period in months. Note CEN Bandwidth package resource cannot be deleted before period. Valid values are 1, 2, 3, 6, 12"
  default = 1
  validation {
    condition     = can(index([1, 2, 3, 6, 12], var.cen_bandwidth_package_period))
    error_message = "Invalid period value. Allowed values are: 1, 2, 3, 6, 12."
  }
}

variable "cen_bandwidth_package_id" {
  type = string
  description = "Pre-created CEN bandwidth package ID. Conflicts with cen_bandwidth_package_name"
  default = null
}

variable "cen_bandwidth_type" {
  type = string
  description = "The method that is used to allocate bandwidth to the cross-region connection"
  default = "DataTransfer"
  validation {
    condition     = can(regex("^(BandwidthPackage|DataTransfer)$", var.cen_bandwidth_type))
    error_message = "Invalid value. Allowed values are: BandwidthPackage, DataTransfer."
  }
}

variable "cen_transit_router_peer_attachment_bandwidth_limit" {
  type = number
  description = "Bandwidth limit assigned to the Transit Router Peer attachment between China and Global"
  default = 100
}

variable "cen_global_geo" {
  type = string
  description = "Name of the Geo where the global transit VPC connecting to CEN is deployed. Valid values are Nort-America, Asia-Pacific, Europe and Australia"
  validation {
    condition     = var.cen_global_geo == null || can(regex("^(North-America|Asia-Pacific|Europe|Australia)$", var.cen_global_geo))
    error_message = "Invalid value. Allowed values are: North-America, Asia-Pacific, Europe, Australia."
  }
  default = null
}

locals {
  global_vpc_cidr_without_mask = element(split("/", var.global_vpc_cidr), 0)
  global_vpc_cidr_replaced     = replace(local.global_vpc_cidr_without_mask, ".", "-")

  china_vpc_cidr_without_mask = element(split("/", var.china_vpc_cidr), 0)
  china_vpc_cidr_replaced     = replace(local.china_vpc_cidr_without_mask, ".", "-")

  china_transit_router = var.cen_instance_id == null ? null : [
    for router in data.alicloud_cen_transit_routers.china[0].transit_routers : router
  ]

  global_transit_router = var.cen_instance_id == null ? null : [
    for router in data.alicloud_cen_transit_routers.global[0].transit_routers : router
  ]

  china_transit_router_attachment = var.cen_instance_id == null ? null : [
    for att in data.alicloud_cen_transit_router_peer_attachments.china[0].attachments : att.transit_router_attachment_id if att.peer_transit_router_id == local.global_transit_router[0].transit_router_id
  ]

  global_transit_router_attachment = var.cen_instance_id == null ? null : [
    for att in data.alicloud_cen_transit_router_peer_attachments.global[0].attachments : att.transit_router_attachment_id if att.peer_transit_router_id == local.china_transit_router[0].transit_router_id
  ]

  global_rtb_existing = [
    for table in data.alicloud_cen_transit_router_route_tables.global_tr[0].tables :
    table if length(regexall("-globalRT",table.transit_router_route_table_name)) > 0
  ]

  china_rtb_existing = [
    for table in data.alicloud_cen_transit_router_route_tables.china_tr[0].tables :
    table if length(regexall("-chinaRT",table.transit_router_route_table_name)) > 0
  ]
}