#!/bin/bash
# Test ROCm functionality in Docker

echo "Testing ROCm Docker integration..."

# Test basic ROCm functionality
echo "1. Testing basic ROCm info..."
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 \
    rocm/rocm-terminal:latest rocminfo | head -20

echo -e "\n2. Testing PyTorch ROCm container..."
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 \
    -v ~/ai-workspace/Projects:/workspace/Projects:rw \
    -v ~/ai-workspace/Models:/workspace/Models:rw \
    rocm/pytorch:latest python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'ROCm available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU device: {torch.cuda.get_device_name(0)}')
    print(f'GPU count: {torch.cuda.device_count()}')
    # Test tensor operations
    x = torch.randn(3, 3).cuda()
    print(f'Created tensor on GPU: {x.device}')
    y = x @ x
    print(f'Matrix multiplication completed on GPU')
else:
    print('No ROCm devices detected')
"

echo -e "\n3. Testing TensorFlow ROCm container..."
docker run --rm --device=/dev/kfd --device=/dev/dri --group-add 44 --group-add 109 \
    -v ~/ai-workspace/Projects:/workspace/Projects:rw \
    -v ~/ai-workspace/Models:/workspace/Models:rw \
    rocm/tensorflow:latest python3 -c "
import tensorflow as tf
print(f'TensorFlow version: {tf.__version__}')
gpus = tf.config.list_physical_devices('GPU')
print(f'GPU devices: {len(gpus)}')
if gpus:
    print(f'GPU details: {gpus[0]}')
else:
    print('No GPU devices detected')
"

echo -e "\n4. Testing Docker Compose services..."
if [ -f ~/ai-workspace/Projects/docker-compose.yml ]; then
    echo "Found docker-compose.yml, testing service start..."
    cd ~/ai-workspace/Projects
    docker compose up -d pytorch-rocm
    sleep 5
    docker compose ps
    echo "Testing ROCm in compose service..."
    docker compose exec pytorch-rocm python3 -c "import torch; print(f'ROCm available in compose: {torch.cuda.is_available()}')"
    docker compose down
else
    echo "No docker-compose.yml found in ~/ai-workspace/Projects/"
    echo "Copy template: cp ~/ai-setup-scripts/ansible/templates/docker-compose.ai-template.yml ~/ai-workspace/Projects/docker-compose.yml"
fi

echo -e "\nROCm Docker test completed!"
echo "If all tests passed, your ROCm Docker setup is working correctly!"
