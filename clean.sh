# Stop all containers
delete_containers()
{
  docker ps -a -q | xargs docker stop 
  # Delete all containers
  docker ps -a -q -f status=exited | xargs docker rm
  docker ps -a
  sudo rm -rf /srv/*
}

delete_images()
{
  docker image ls
  docker images -a -q | xargs docker rmi -f
  docker image ls
}

delete_docker()
{
  sudo apt-get purge -y docker-ce docker-ce-cli docker-ce-rootless-extras
  sudo apt-get autoremove -y docker-ce docker-ce-cli docker-ce-rootless-extras

  sudo rm $(which docker-compose)
  sudo gpasswd -d ${USER} docker
  sudo delgroup docker
}

delete_volumes()
{
  docker volume prune --force
}
delete_all()
{
  delete_containers
  delete_images
  delete_volumes
  delete_docker
}

case "$1" in
  c) delete_containers;;
  i) delete_images;;
  v) delete_volumes;;
  d) delete_docker;;
  x) delete_all;;
  *) echo "${0} [option]\n"\
      " c = rm all docker containers\n"\
      " i = rm all docker images\n"\
      " v = rm all docker volumes\n"\
      " d = docker uninstall\n"\
      " x = do it all\n"\
      " * = anything else gets you this menu";;
esac
