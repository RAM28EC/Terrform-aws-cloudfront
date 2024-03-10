resource "aws_key_pair" "client_key" {
    key_name = "prodios"
    public_key = file("../modules/key/prodios.pub")
}
