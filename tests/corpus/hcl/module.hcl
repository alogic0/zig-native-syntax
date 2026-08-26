module "network" {
  source = "./modules/network"
  cidr   = "10.0.0.0/16"
}

output "network_id" {
  value = module.network.id
}
