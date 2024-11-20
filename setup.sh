#Setup github acces to push modification if needed
ssh-keygen -t ed25519
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519.pub
cp ~/.ssh/id_ed25519.pub /media/$USER/Ventoy/
sudo chmod 400 ~/.ssh/id_ed25519

#Make cp of ssh public key from host
cp key/.pub ~/.ssh/authorized_key