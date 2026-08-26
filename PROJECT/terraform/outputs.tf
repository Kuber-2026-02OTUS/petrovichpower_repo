output "bastion_public_ip" {
  description = "Статический внешний IP бастиона"
  value       = yandex_vpc_address.bastion_public_ip.external_ipv4_address[0].address
}

output "bastion_private_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].ip_address
}

output "gitlab_private_ip" {
  value = yandex_compute_instance.gitlab.network_interface[0].ip_address
}

output "nexus_private_ip" {
  value = yandex_compute_instance.nexus.network_interface[0].ip_address
}

output "postgres_private_ip" {
  value = yandex_compute_instance.postgres.network_interface[0].ip_address
}

output "masters_private_ips" {
  value = yandex_compute_instance.master[*].network_interface[0].ip_address
}

output "workers_private_ips" {
  value = yandex_compute_instance.worker[*].network_interface[0].ip_address
}