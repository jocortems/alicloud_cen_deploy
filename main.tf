# 1. Create AliCloud CEN and Transit Routers

resource "alicloud_cen_instance" "cen" {
  cen_instance_name = var.cen_name
  provider          = alicloud.global
}

# 1a. Retrieve Global Master and Slave Zones
data "alicloud_cen_transit_router_available_resources" "global" {
  provider   = alicloud.global
  depends_on = [alicloud_cen_instance.cen]
}

# 1b. Retrieve China Master and Slave Zones
data "alicloud_cen_transit_router_available_resources" "china" {
  provider   = alicloud.china
  depends_on = [alicloud_cen_instance.cen]
}

# 1c. Create vSwitch for Transit Router in Global Master Zone
resource "alicloud_vswitch" "global_master" {
  provider     = alicloud.global
  vswitch_name = format("%s-masterCENRouter", var.cen_name)
  vpc_id       = var.global_vpc_id
  cidr_block   = cidrsubnet(var.global_vpc_cidr, 5, 14)
  zone_id      = data.alicloud_cen_transit_router_available_resources.global.resources[0].master_zones[0]
}

# 1d. Create vSwitch for Transit Router in Global Slave Zone
resource "alicloud_vswitch" "global_slave" {
  provider     = alicloud.global
  vswitch_name = format("%s-slaveCENRouter", var.cen_name)
  vpc_id       = var.global_vpc_id
  cidr_block   = cidrsubnet(var.global_vpc_cidr, 5, 15)
  zone_id      = data.alicloud_cen_transit_router_available_resources.global.resources[0].slave_zones[1]
}

# 1e. Create vSwitch for Transit Router in China Master Zone
resource "alicloud_vswitch" "china_master" {
  provider     = alicloud.china
  vswitch_name = format("%s-masterCENRouter", var.cen_name)
  vpc_id       = var.china_vpc_id
  cidr_block   = cidrsubnet(var.china_vpc_cidr, 5, 14)
  zone_id      = data.alicloud_cen_transit_router_available_resources.china.resources[0].master_zones[0]
}

# 1f. Create vSwitch for Transit Router China in Slave Zone
resource "alicloud_vswitch" "china_slave" {
  provider     = alicloud.china
  vswitch_name = format("%s-slaveCENRouter", var.cen_name)
  vpc_id       = var.china_vpc_id
  cidr_block   = cidrsubnet(var.china_vpc_cidr, 5, 15)
  zone_id      = data.alicloud_cen_transit_router_available_resources.china.resources[0].slave_zones[1]
}


# 1g. Create CEN Transit Router in Region 1
resource "alicloud_cen_transit_router" "global_tr" {
  provider            = alicloud.global
  cen_id              = alicloud_cen_instance.cen.id
  transit_router_name = format("%s-globalCENRouter", var.cen_name)  
}

# 1h. Create CEN Transit Router in Region 2 - wait for Transit Router Region 1 to be created to avoid blocking error
resource "alicloud_cen_transit_router" "china_tr" {
  provider            = alicloud.china
  depends_on          = [alicloud_cen_transit_router.global_tr]
  cen_id              = alicloud_cen_instance.cen.id
  transit_router_name = format("%s-chinaCENRouter", var.cen_name)
}

# 2. Attach VPC to Transit Router
# 2a. Create VPC Attachment to Global Transit Router
resource "alicloud_cen_transit_router_vpc_attachment" "global" {
  provider                        = alicloud.global
  cen_id                          = alicloud_cen_instance.cen.id
  transit_router_id               = alicloud_cen_transit_router.global_tr.transit_router_id
  vpc_id                          = var.global_vpc_id
  transit_router_attachment_name  = format("%s-tr-global-attachment", var.cen_name)

  zone_mappings {
    vswitch_id = alicloud_vswitch.global_master.id
    zone_id    = data.alicloud_cen_transit_router_available_resources.global.resources[0].master_zones[0]
  }
  zone_mappings {
    vswitch_id = alicloud_vswitch.global_slave.id
    zone_id    = data.alicloud_cen_transit_router_available_resources.global.resources[0].slave_zones[1]
  }  
}

# 2b. Create VPC Attachment to China Transit Router
resource "alicloud_cen_transit_router_vpc_attachment" "china" {
  provider                        = alicloud.china
  cen_id                          = alicloud_cen_instance.cen.id
  transit_router_id               = alicloud_cen_transit_router.china_tr.transit_router_id
  vpc_id                          = var.china_vpc_id
  transit_router_attachment_name  = format("%s-tr-china-attachment", var.cen_name)

  zone_mappings {
    vswitch_id = alicloud_vswitch.china_master.id
    zone_id    = data.alicloud_cen_transit_router_available_resources.china.resources[0].master_zones[0]
  }
  zone_mappings {
    vswitch_id = alicloud_vswitch.china_slave.id
    zone_id    = data.alicloud_cen_transit_router_available_resources.china.resources[0].slave_zones[1]
  }
}

# 3. Create and associate Route tables
# 3a. Create Transit Router Route Table in Global Region
resource "alicloud_cen_transit_router_route_table" "global_rtb" {
  provider                        = alicloud.global
  transit_router_id               = alicloud_cen_transit_router.global_tr.transit_router_id
  transit_router_route_table_name = format("%s-globalRT", var.cen_name)  
}

# 3b. Create Transit Router Route Table in China Region
resource "alicloud_cen_transit_router_route_table" "china_rtb" {
  provider                        = alicloud.china
  transit_router_id               = alicloud_cen_transit_router.china_tr.transit_router_id
  transit_router_route_table_name = format("%s-chinaRT", var.cen_name)  
}

# 3c. Create Intra-Region Route Table Association in Global Region
resource "alicloud_cen_transit_router_route_table_association" "global_rtb_association" {
  provider                      = alicloud.global
  depends_on                    = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.global_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_vpc_attachment.global.transit_router_attachment_id  
}

# 3d. Create Intra-Region Route Table Association in China Region
resource "alicloud_cen_transit_router_route_table_association" "china_rtb_association" {
  provider                      = alicloud.china
  depends_on                    = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.china_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_vpc_attachment.china.transit_router_attachment_id
}

# 3e. Create Intra-Region Route Table Propagation in Global Region
resource "alicloud_cen_transit_router_route_table_propagation" "global_rtb_propagation" {
  provider                      = alicloud.global
  depends_on                    = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.global_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_vpc_attachment.global.transit_router_attachment_id
}

# 3f. Create Intra-Region Route Table Propagation in China Region
resource "alicloud_cen_transit_router_route_table_propagation" "china_rtb_propagation" {
  provider                      = alicloud.china
  depends_on                    = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.china_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_vpc_attachment.china.transit_router_attachment_id
}


# 4. Allocate Bandwidth to the CEN
# 4a. Create Bandwidth Package Plan and Associate with CEN
resource "alicloud_cen_bandwidth_package" "cen_bandwidth_package" {
  count                      = var.cen_bandwidth_package_name == null ? 0 : 1
  provider                   = alicloud.global
  cen_bandwidth_package_name = var.cen_bandwidth_package_name  
  bandwidth                  = var.cen_bandwidth_package_bandwdith
  period                     = var.cen_bandwidth_package_period
  geographic_region_a_id     = var.cen_global_geo
  geographic_region_b_id     = "China"
}

#5b. Attach the bandwidth package to the CEN
resource "alicloud_cen_bandwidth_package_attachment" "cen_bandwidth_package_attachment" {
  count                = var.cen_bandwidth_package_id == null || var.cen_bandwidth_package_name == null  ? 0 : 1
  provider             = alicloud.global
  instance_id          = alicloud_cen_instance.cen.id
  bandwidth_package_id = var.cen_bandwidth_package_name == null ? var.cen_bandwidth_package_id : alicloud_cen_bandwidth_package.cen_bandwidth_package[0].id
}

#5c. Assign a bandwidth limit from the bandwidth package to the CEN
resource "alicloud_cen_bandwidth_limit" "cen_bandwidth_limit" {
  count       = var.cen_bandwidth_package_id == null || var.cen_bandwidth_package_name == null  ? 0 : 1
  provider    = alicloud.global
  instance_id = alicloud_cen_instance.cen.id
  region_ids  = [
    var.ali_china_region,
    var.ali_global_region,
  ]
  bandwidth_limit = var.cen_bandwidth_limit
  depends_on = [
    alicloud_cen_bandwidth_package_attachment.cen_bandwidth_package_attachment[0],
    alicloud_cen_transit_router_vpc_attachment.global,
    alicloud_cen_transit_router_vpc_attachment.china,
  ]
}

# 5. Create Cross-Region Connections
# 5a. Peer Global and China transit routers
resource "alicloud_cen_transit_router_peer_attachment" "global_to_china" {
  provider                       = alicloud.global
  cen_id                         = alicloud_cen_instance.cen.id
  transit_router_id              = alicloud_cen_transit_router.global_tr.transit_router_id
  peer_transit_router_region_id  = var.ali_china_region
  peer_transit_router_id         = alicloud_cen_transit_router.china_tr.transit_router_id
  cen_bandwidth_package_id       = var.cen_bandwidth_type == "DataTransfer" ? null : var.cen_bandwidth_package_id != null ? var.cen_bandwidth_package_id : alicloud_cen_bandwidth_package.cen_bandwidth_package[0].id
  bandwidth                      = var.cen_transit_router_peer_attachment_bandwidth_limit
  bandwidth_type                 = var.cen_bandwidth_type
  transit_router_attachment_name = "${var.ali_global_region}-to-${var.ali_china_region}"

  auto_publish_route_enabled      = true
  route_table_association_enabled = false
  route_table_propagation_enabled = false

  timeouts {
    create = "5m"
    delete = "5m"
    update = "5m"
  }  
}

# 5b. Create Cross-Region Route Table Association in Global Region
resource "alicloud_cen_transit_router_route_table_association" "global_xregion_rtb_association" {
  provider                      = alicloud.global
  depends_on                    = [alicloud_cen_transit_router_vpc_attachment.global]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.global_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_peer_attachment.global_to_china.transit_router_attachment_id  
}

# 5c. Create Cross-Region Route Table Association in China Region
resource "alicloud_cen_transit_router_route_table_association" "china_xregion_rtb_association" {
  provider                      = alicloud.china
  depends_on                    = [alicloud_cen_transit_router_vpc_attachment.china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.china_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_peer_attachment.global_to_china.transit_router_attachment_id  
}

# 5d. Create Cross-Region Route Table Propagation in Global Region
resource "alicloud_cen_transit_router_route_table_propagation" "global_xregion_rtb_propagation" {
  provider                      = alicloud.global
  depends_on                    = [alicloud_cen_transit_router_vpc_attachment.global]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.global_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_peer_attachment.global_to_china.transit_router_attachment_id
}

# 5e. Create Cross-Region Route Table Propagation in China Region
resource "alicloud_cen_transit_router_route_table_propagation" "china_xregion_rtb_propagation" {
  provider                      = alicloud.china
  depends_on                    = [alicloud_cen_transit_router_vpc_attachment.china]
  transit_router_route_table_id = alicloud_cen_transit_router_route_table.china_rtb.transit_router_route_table_id
  transit_router_attachment_id  = alicloud_cen_transit_router_peer_attachment.global_to_china.transit_router_attachment_id
}

# 5f. Retrieve Transit VPC Route Table in Global Region
data "alicloud_route_tables" "global_transit_rtb" {
  provider = alicloud.global
  vpc_id   = var.global_vpc_id
}

# 5g. Retrieve Transit VPC Route Table in China Region
data "alicloud_route_tables" "china_transit_rtb" {
  provider = alicloud.china
  vpc_id   = var.china_vpc_id  
}

# 5h. Create Route from Transit VPC Global Region to Transit VPC China Region
resource "alicloud_route_entry" "global_to_china" {
  provider              = alicloud.global
  depends_on            = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  route_table_id        = data.alicloud_route_tables.global_transit_rtb.tables[0].route_table_id
  destination_cidrblock = var.china_vpc_cidr
  nexthop_type          = "Attachment" # Transit Router
  nexthop_id            = alicloud_cen_transit_router_vpc_attachment.global.transit_router_attachment_id
}

# 5i. Create Route from Transit VPC China Region to Transit VPC Global Region
resource "alicloud_route_entry" "china_to_global" {
  provider              = alicloud.china
  depends_on            = [alicloud_cen_transit_router_peer_attachment.global_to_china]
  route_table_id        = data.alicloud_route_tables.china_transit_rtb.tables[0].route_table_id
  destination_cidrblock = var.global_vpc_cidr
  nexthop_type          = "Attachment" # Transit Router
  nexthop_id            = alicloud_cen_transit_router_vpc_attachment.china.transit_router_attachment_id  
}