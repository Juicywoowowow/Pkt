use anyhow::Result;
use clap::{Parser, Subcommand};
use crate::container::ContainerManager;
use crate::storage::Storage;

#[derive(Parser)]
#[command(name = "dock")]
#[command(about = "Lightweight container manager for Termux", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Create a new container
    Create {
        /// Container name
        name: String,
        /// Path to Python script
        script: String,
    },
    /// Start a container
    Start {
        /// Container name
        name: String,
        /// Port mapping (host:container)
        #[arg(short, long)]
        port: Option<String>,
    },
    /// Stop a container
    Stop {
        /// Container name
        name: String,
    },
    /// List all containers
    List,
    /// Enter a container shell
    Enter {
        /// Container name
        name: String,
    },
    /// View container logs
    Logs {
        /// Container name
        name: String,
    },
    /// Remove a container
    Remove {
        /// Container name
        name: String,
    },
    /// Update dock from git
    Update,
}

impl Cli {
    pub async fn execute(self) -> Result<()> {
        let storage = Storage::new()?;
        let manager = ContainerManager::new(storage);

        match self.command {
            Commands::Create { name, script } => manager.create(&name, &script).await?,
            Commands::Start { name, port } => manager.start(&name, port).await?,
            Commands::Stop { name } => manager.stop(&name).await?,
            Commands::List => manager.list().await?,
            Commands::Enter { name } => manager.enter(&name).await?,
            Commands::Logs { name } => manager.logs(&name).await?,
            Commands::Remove { name } => manager.remove(&name).await?,
            Commands::Update => manager.update().await?,
        }

        Ok(())
    }
}
