# Add to the upgrade() function:

op.create_table(
    "generated_reports",
    sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
    sa.Column("report_id", sa.String(255), nullable=False, unique=True),
    sa.Column("title", sa.String(500), nullable=False),
    sa.Column("content", sa.Text(), nullable=False),
    sa.Column("metadata", postgresql.JSONB(), default={}),
    sa.Column("threat_count", sa.Integer(), default=0),
    sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    sa.Column("created_by", sa.String(255), nullable=True),
    sa.Column("updated_by", sa.String(255), nullable=True),
    sa.PrimaryKeyConstraint("id"),
    sa.UniqueConstraint("report_id"),
)
