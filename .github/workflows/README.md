# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating AUR package management.

## Update Git Packages Workflow

The `update-git-packages.yml` workflow automatically updates git packages by:

1. **Building packages in Docker containers** using the existing Dockerfiles
2. **Updating PKGBUILD and .SRCINFO files** with the latest git versions
3. **Committing changes** to this repository
4. **Pushing updates to AUR** (if configured)

### Triggers

- **Scheduled**: Runs daily at 2 AM UTC
- **Manual**: Can be triggered manually with optional package selection

### Setup Requirements

#### 1. Repository Secrets

Add these secrets to your GitHub repository settings:

- `AUR_USERNAME`: Your AUR username
- `AUR_SSH_PRIVATE_KEY`: Your AUR SSH private key

#### 2. AUR SSH Key Setup

1. Generate an SSH key pair for AUR access:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/aur_key
   ```

2. Add the public key to your AUR account:
   - Copy the contents of `~/.ssh/aur_key.pub`
   - Go to https://aur.archlinux.org/account/
   - Add the SSH key to your account

3. Add the private key to GitHub secrets:
   - Copy the contents of `~/.ssh/aur_key`
   - Add as `AUR_SSH_PRIVATE_KEY` secret

### How It Works

1. **Package Discovery**: Finds all directories ending with `-git`
2. **Docker Build**: Builds each package using its Dockerfile
3. **Version Update**: Runs `makepkg --printsrcinfo` to update versions
4. **File Extraction**: Copies updated PKGBUILD and .SRCINFO from containers
5. **Repository Update**: Commits changes to this repository
6. **AUR Push**: Pushes updates to AUR repositories (if configured)

### Supported Packages

The workflow automatically detects and processes these git packages:

- `openmohaa-git`
- `rot8-git`
- `stable-diffusion-cpp-vulkan-git`

### Manual Execution

You can manually trigger the workflow:

1. Go to the "Actions" tab in your GitHub repository
2. Select "Update Git Packages"
3. Click "Run workflow"
4. Optionally specify a single package name
5. Click "Run workflow"

### Troubleshooting

#### Workflow Fails to Build

- Check that Dockerfiles exist and are valid
- Verify build dependencies are available
- Check container logs for specific errors

#### AUR Push Fails

- Verify AUR credentials are correctly set
- Check SSH key permissions and format
- Ensure AUR package names match PKGBUILD pkgname

#### No Changes Detected

- This is normal if packages are already up to date
- Check if `pkgver()` functions are working correctly
- Verify git repositories are accessible

### Security Notes

- SSH keys are stored as GitHub secrets and are encrypted
- Keys are only used during workflow execution
- Containers are cleaned up after each run
- No persistent storage of sensitive data

### Customization

To add new git packages:

1. Create a directory named `package-name-git`
2. Add a valid Dockerfile
3. Include PKGBUILD and .SRCINFO files
4. The workflow will automatically detect and process it

To modify the schedule:

Edit the `cron` expression in the workflow file:
```yaml
schedule:
  - cron: '0 2 * * *'  # Daily at 2 AM UTC
```