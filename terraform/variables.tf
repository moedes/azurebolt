variable "Resource_Group" {
    default = "Mozes_RG"
    type = string
}

variable "virtual_network" {
    default = "mozes-net"
    type = string
}

variable "pe_subnet" {
    default = "PE_Network"
    type = string
}