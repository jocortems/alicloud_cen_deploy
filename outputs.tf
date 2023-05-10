output "cen_instance" {
  description = "Created CEN Instance object"
  value = var.cen_instance_id != null ? var.cen_instance_id : alicloud_cen_instance.cen[0]
}

output "cen_bandwidth_package" {
  description = "Created CEN Bandwidth Package object"
  value = alicloud_cen_bandwidth_package.cen_bandwidth_package
}

output "cen_global_transit_router" {
  description = "Transit router object in Global Region"
  value = var.cen_instance_id != null ? local.global_transit_router : alicloud_cen_transit_router.global_tr[0]
}

output "cen_china_transit_router" {
  description = "Transit router object in China Region"
  value = var.cen_instance_id != null ? local.china_transit_router : alicloud_cen_transit_router.global_tr[0]
}

output "cen_china_transit_router_route_table" {
  description = "Transit router route table object in China Region"
  value = alicloud_cen_transit_router_route_table.china_rtb
}

output "cen_global_transit_router_route_table" {
  description = "Transit router route table object in Global Region"
  value = alicloud_cen_transit_router_route_table.global_rtb
}