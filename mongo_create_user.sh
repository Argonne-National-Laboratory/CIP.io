docker exec -it mongodb mongo -u root -p root --eval db.getSiblingDB("admin").createUser( { user: "myuser2", pwd: "mypwd2", roles: [ { role: "readWrite", db: "cipio_test" } ] })
docker exec -it mongodb mongo -u root -p root --eval db.getSiblingDB("cipio_test").test.insertOne({ x: 1 })
