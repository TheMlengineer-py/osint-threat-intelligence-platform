"""Initial schema creation.

Revision ID: 001_initial_schema
Revises:
Create Date: 2024-01-01 00:00:00.000000
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Create users table
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("username", sa.String(255), nullable=False, unique=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("is_superuser", sa.Boolean(), default=False),
        sa.Column("is_analyst", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("created_by", sa.String(255), nullable=True),
        sa.Column("updated_by", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("username"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_users_username", "users", ["username"])
    op.create_index("ix_users_email", "users", ["email"])

    # Create threats table
    op.create_table(
        "threats",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("source", sa.String(255), nullable=False),
        sa.Column("source_url", sa.String(2048), nullable=True),
        sa.Column("threat_type", sa.String(100), nullable=False),
        sa.Column("threat_actor", sa.String(255), nullable=True),
        sa.Column("campaign", sa.String(255), nullable=True),
        sa.Column("severity_score", sa.Float(), default=0.0),
        sa.Column("confidence_score", sa.Float(), default=0.0),
        sa.Column("risk_level", sa.String(50), default="low"),
        sa.Column("indicators", postgresql.JSONB(), default={}),
        sa.Column("tags", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("mitre_techniques", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("first_seen", sa.DateTime(), nullable=True),
        sa.Column("last_seen", sa.DateTime(), nullable=True),
        sa.Column("related_threats", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("status", sa.String(50), default="open"),
        sa.Column("analyst_notes", sa.Text(), nullable=True),
        sa.Column("raw_data", postgresql.JSONB(), nullable=True),
        sa.Column("embedding_vector_id", sa.String(255), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("created_by", sa.String(255), nullable=True),
        sa.Column("updated_by", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_threats_title", "threats", ["title"])
    op.create_index("ix_threats_source", "threats", ["source"])
    op.create_index("ix_threats_threat_type", "threats", ["threat_type"])
    op.create_index("ix_threats_status", "threats", ["status"])
    op.create_index("ix_threats_created_at", "threats", ["created_at"])
    op.create_index(
        "ix_threat_severity_created", "threats", ["severity_score", "created_at"]
    )
    op.create_index("ix_threat_type_status", "threats", ["threat_type", "status"])

    # Create indicators table
    op.create_table(
        "indicators",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("indicator_type", sa.String(100), nullable=False),
        sa.Column("value", sa.String(1024), nullable=False),
        sa.Column("classification", sa.String(100), nullable=False),
        sa.Column("confidence_score", sa.Float(), default=0.0),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("threat_id", sa.String(255), nullable=True),
        sa.Column("sources", postgresql.JSONB(), default={}),
        sa.Column("detections", postgresql.JSONB(), default={}),
        sa.Column("first_reported", sa.DateTime(), nullable=True),
        sa.Column("last_reported", sa.DateTime(), nullable=True),
        sa.Column("raw_data", postgresql.JSONB(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("created_by", sa.String(255), nullable=True),
        sa.Column("updated_by", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_indicators_indicator_type", "indicators", ["indicator_type"])
    op.create_index("ix_indicators_value", "indicators", ["value"])
    op.create_index("ix_indicators_classification", "indicators", ["classification"])
    op.create_index(
        "ix_indicator_type_value", "indicators", ["indicator_type", "value"]
    )

    # Create reports table
    op.create_table(
        "reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("report_type", sa.String(100), nullable=False),
        sa.Column("status", sa.String(50), default="draft"),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("executive_summary", sa.Text(), nullable=True),
        sa.Column("findings", sa.Text(), nullable=True),
        sa.Column("recommendations", sa.Text(), nullable=True),
        sa.Column("threat_ids", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("indicator_ids", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("report_date", sa.DateTime(), nullable=False),
        sa.Column("coverage_start", sa.DateTime(), nullable=True),
        sa.Column("coverage_end", sa.DateTime(), nullable=True),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.Column("published_by", sa.String(255), nullable=True),
        sa.Column("generated_by_agent", sa.String(255), nullable=True),
        sa.Column("generation_metadata", postgresql.JSONB(), default={}),
        sa.Column("pdf_path", sa.String(1024), nullable=True),
        sa.Column("json_data", postgresql.JSONB(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("created_by", sa.String(255), nullable=True),
        sa.Column("updated_by", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reports_title", "reports", ["title"])
    op.create_index("ix_reports_report_date", "reports", ["report_date"])

    # Create chat_histories table
    op.create_table(
        "chat_histories",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("session_id", sa.String(255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("response", sa.Text(), nullable=False),
        sa.Column("message_type", sa.String(50), default="query"),
        sa.Column("related_threats", postgresql.ARRAY(sa.String), default=[]),
        sa.Column("context_data", postgresql.JSONB(), default={}),
        sa.Column("model_used", sa.String(255), nullable=False),
        sa.Column("tokens_used", sa.String(255), nullable=True),
        sa.Column("latency_ms", sa.String(255), nullable=True),
        sa.Column("timestamp", sa.DateTime(), nullable=False),
        sa.Column("is_feedback_provided", sa.Boolean(), default=False),
        sa.Column("feedback", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("created_by", sa.String(255), nullable=True),
        sa.Column("updated_by", sa.String(255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_histories_user_id", "chat_histories", ["user_id"])
    op.create_index("ix_chat_histories_session_id", "chat_histories", ["session_id"])
    op.create_index("ix_chat_histories_timestamp", "chat_histories", ["timestamp"])


def downgrade() -> None:
    """Downgrade database schema."""
    op.drop_index("ix_chat_histories_timestamp", "chat_histories")
    op.drop_index("ix_chat_histories_session_id", "chat_histories")
    op.drop_index("ix_chat_histories_user_id", "chat_histories")
    op.drop_table("chat_histories")

    op.drop_index("ix_reports_report_date", "reports")
    op.drop_index("ix_reports_title", "reports")
    op.drop_table("reports")

    op.drop_index("ix_indicator_type_value", "indicators")
    op.drop_index("ix_indicators_classification", "indicators")
    op.drop_index("ix_indicators_value", "indicators")
    op.drop_index("ix_indicators_indicator_type", "indicators")
    op.drop_table("indicators")

    op.drop_index("ix_threat_type_status", "threats")
    op.drop_index("ix_threat_severity_created", "threats")
    op.drop_index("ix_threats_created_at", "threats")
    op.drop_index("ix_threats_status", "threats")
    op.drop_index("ix_threats_threat_type", "threats")
    op.drop_index("ix_threats_source", "threats")
    op.drop_index("ix_threats_title", "threats")
    op.drop_table("threats")

    op.drop_index("ix_users_email", "users")
    op.drop_index("ix_users_username", "users")
    op.drop_table("users")
